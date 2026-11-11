"""The factions' working buildings, modelled (phase 2 of the graphics pass; the user, 2026-11-10: "I still see some gross
recolors. Why not use blender again?"; the landers alone keep their repaint): each building a role, Kessler-Hayashi's and
Grubstake's builds of it apart, KH clean corporate blue-grey with cyan lights, Grubstake patched ochre scrap with amber
(palette() in faction_buildings.py; ochre lpkit's grimed paint).
  fabricator  3x3, the parts maker: KH a sealed fab module, a print gantry crossing under its glazed roof; Grubstake an
              open scrap press, its ram stamping (16 frames: its working animation).
  radar       3x3, its head turning through 32 steps (a radar's sprite turns whole): KH a phased-array mast, Grubstake a
              patched dish on a tripod.
  drill       3x3, four directions (its output north at yaw 0), 16 frames each: KH's sealed bore unit, its collar turning
              (Grubstake's drill is the strip drill's gantry, turning_buildings.py).
  flamer      2x3, its base in four directions and its head in 64 on a pivot at the centre: KH an armoured fuel-fed
              flame turret, Grubstake a drum-fed scrap flamer.
  pylon       1x1, one direction and its wire points (posts.json): KH a composite mast, Grubstake a welded pipe tripod.
  turret      2x2, a base once and a head in 64 directions (north first, clockwise): KH's laser turret (a lens turret on
              a hexagonal ring) and gun-turret (twin autocannon), Grubstake's turret (a gun nest of scrap, one barrel).
  generator   2x2, the camp's power: KH a fusion cell, its core lit, vanes turning on its crown; Grubstake a scrap
              genset, its radiator fan turning (16 frames, always running).
  depot       4x4, one picture (a container): KH a sealed landing pad, its cargo iris, a crane; Grubstake a plated pad on
              oil-drum stilts, an A-frame hoist, tyre bumpers, crates (clay concepts: kh-a, kh-b, gs-a, gs-b).
  launchpad   9x9, one picture: KH an electromagnetic launch tube in a ring of capacitor banks, its gantry; Grubstake a
              lattice derrick over a pit whose lid is a ship's hull section (concepts as the depot's).

    Blender -b -P tools/blender/faction_works.py -- <what> <kh|gs> <out_dir>      (LP_CLAY=1: one grey, for silhouettes)
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/<serenity|grubstake>/<what>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
WHAT, F, out = args[0], args[1], args[2]
CLAY = os.environ.get("LP_CLAY") == "1"
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
TEX = os.path.isdir(lptex.TEX) and not CLAY
B, cyl, rod, sph, tor = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere, lpkit.torus


def palette(f):
    """A faction's materials: hull, trim, dark, steel, accent, light, glass."""
    W = lpkit.palette_worn()
    if f == "kh":
        # (lpkit's worn paint in the corporation's blue: PaintedMetal006 is a white paint, and a hue turned on it stayed
        # grey, a pale concrete at 0.8 texture scale and near black at 0.42 value.)
        hull = lpkit.worn("kh-hull", (0.13, 0.19, 0.27), metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.3)
        trim = lpkit.worn("kh-trim", (0.28, 0.3, 0.32), metal=0.4, rough=0.5, seams=2, rivets=False, wear=0.35)
        accent = lpkit.worn("kh-haz", (0.62, 0.5, 0.1), metal=0.2, rough=0.6, seams=8, rivets=False, wear=0.3)
        light = lpkit.mat("kh-light", (0.2, 0.5, 0.6), metal=0.2, rough=0.3, emit=(0.45, 0.85, 1.0), strength=0.0, grime=0.0)
        glass = lpkit.mat("kh-glass", (0.02, 0.035, 0.045), metal=0.6, rough=0.12, emit=(0.3, 0.7, 0.9), strength=0.0, grime=0.0)
    else:
        hull = lpkit.mat("gs-hull", (0.3, 0.18, 0.045), metal=0.3, rough=0.65, grime=0.85)
        trim = lptex.textured("gs-rust", "MetalPlates013", val=0.6, scale=0.8, edge=(0.4, 0.33, 0.25)) if TEX \
            else lpkit.worn("gs-rust", (0.25, 0.11, 0.05), metal=0.5, rough=0.7, seams=6)
        accent = lpkit.worn("gs-red", (0.13, 0.05, 0.03), metal=0.35, rough=0.7, seams=6, rivets=True, wear=0.4)
        light = lpkit.mat("gs-light", (0.6, 0.4, 0.05), metal=0.1, rough=0.3, emit=(1.0, 0.62, 0.15), strength=0.0, grime=0.0)
        glass = lpkit.mat("gs-glass", (0.08, 0.06, 0.03), metal=0.1, rough=0.2, emit=(1.0, 0.55, 0.15), strength=0.0, grime=0.0)
    # Burlap for sandbags: a coarse cloth (rough, dull, a brick-bond seam for its weave), tan, dirtied.
    cloth = lpkit.worn(f + "-cloth", (0.3, 0.25, 0.16), metal=0.0, rough=0.95, seams=14, wear=0.3, streaks=0.6, rivets=False)
    # (Gunmetal and a shield's dark paint, 0.2.325: Grubstake's gun nest and flamer read "transparent" at the game's zoom,
    # the user's rating, 2026-11-11: the shield in the hull's ochre was the grass's own olive-brown and the pale steel
    # pedestal and lance carried the deck's tone, so both read as holes onto what lay under them.)
    gunmetal = lpkit.worn(f + "-gunmetal", (0.06, 0.06, 0.065), metal=0.25, rough=0.7, seams=3, rivets=False, wear=0.25)
    shield = lpkit.worn(f + "-shield", (0.05, 0.045, 0.04), metal=0.45, rough=0.6, seams=4, rivets=True, wear=0.3)
    # (A skid in weathered mid-grey steel, lighter than its shadow: near black, the gun nest's and flamer's plates read as
    # a shadow laid over the turret, "Seems like the base plate shadow is applied on top of the turret?", the user's
    # rating, 2026-11-11.)
    skid = lpkit.worn(f + "-skid", (0.3, 0.28, 0.24), metal=0.5, rough=0.6, seams=4, rivets=True, wear=0.45)
    P = {"skid": skid, "gunmetal": gunmetal, "shield": shield, "hull": hull, "trim": trim, "dark": W["dark"], "steel": W["steel"], "accent": accent, "light": light,
         "glass": glass, "rubber": W["rubber"], "hazard": W["hazard"], "cloth": cloth}
    if CLAY:
        clay = lpkit.mat("clay", (0.5, 0.5, 0.5), metal=0.0, rough=0.7, grime=0.0)
        P = {k: (v if k in ("light", "glass") else clay) for k, v in P.items()}
    return P


P = palette(F.split("-")[0])   # (a concept is named for its faction: kh-..., gs-...)


def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]


def octa(r, h, x, y, z, m, sx=1.0, sy=1.0):
    """A chamfered block: an octagon prism (Factorio's machines' corners)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(x, y, z + h / 2), rotation=(0, 0, math.pi / 8))
    o = bpy.context.object; o.scale = (sx, sy, 1.0); o.data.materials.append(m); return o


# --- Props: Poly Haven's CC0 models (LP_PROPS, tools/blender/polyhaven_get.py), toned into the palette; none without them.
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
    # (Real metres to tiles, a tile a metre and a half, and Factorio's exaggeration, 2.5: a prop at its size read as a speck.)
    o.location = at; o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], math.radians(rz)); o.scale = (2.5 / 1.5 * k,) * 3
    return o


# --- Machine parts: what vanilla's machines are dense with.
def motor(x, y, z, r, L, m, fins, axis="x"):
    """An electric motor lying along an axis: a ribbed can, an end bell, a shaft stub, a terminal box."""
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0)
    dx, dy = (L / 2, 0) if axis == "x" else (0, L / 2)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=L, location=(x, y, z + r), rotation=rot)
    bpy.context.object.data.materials.append(m)
    for k in range(int(L / 0.09)):
        t = -L / 2 + 0.06 + k * 0.09
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.018, location=(x + (t if axis == "x" else 0), y + (t if axis == "y" else 0), z + r),
                                         rotation=rot)
        bpy.context.object.data.materials.append(fins)
    B(r * 0.9, r * 0.7, r * 0.5, x, y, z + 2 * r - 0.02, fins)


def gear(x, y, z, r, m, teeth=14, axis="y"):
    """A gear wheel on edge: a disc and its teeth."""
    rot = (math.pi / 2, 0, 0) if axis == "y" else (0, math.pi / 2, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r, depth=0.06, location=(x, y, z), rotation=rot)
    bpy.context.object.data.materials.append(m)
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        if axis == "y":
            o = B(0.05, 0.06, 0.05, x + math.cos(a) * r, y - 0.03, z + math.sin(a) * r - 0.025, m, bevel=0.0)
            o.rotation_euler = (0, -a, 0)
        else:
            o = B(0.06, 0.05, 0.05, x - 0.03, y + math.cos(a) * r, z + math.sin(a) * r - 0.025, m, bevel=0.0)
            o.rotation_euler = (a, 0, 0)
    cyl(r * 0.3, 0.1, x, y - 0.05 if axis == "y" else y, z, m, verts=12, rot=rot)


def pipe(pts, r, m, flange=None):
    """A pipe run through points, a flange at each joint."""
    for a, b in zip(pts, pts[1:]):
        rod(a, b, r, m, verts=12)
    for p in pts[1:-1] if flange else ():
        sph(r * 1.25, p[0], p[1], p[2], flange)


def lie(r, L, x, y, z, m, axis="x", verts=12):
    """A cylinder lying along an axis, centred on (x, y, z) (lpkit.cyl stands on z: turned, it rose by half its length)."""
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=L, location=(x, y, z), rotation=rot)
    o = bpy.context.object; o.data.materials.append(m); return o


def gauge(x, y, z, m, face, normal="-y"):
    lie(0.07, 0.03, x, y, z, m, "y", 16)
    lie(0.055, 0.035, x, y - 0.006, z, face, "y", 16)


def scatter(objs, mats, dark, metal, seed, density=5.0):
    """Small parts seeded over the large upward and outward faces of objs whose material is in mats (junction boxes, vents,
    hatches, bolts), at a 3x3 machine's scale: what made the cannon read made, not modelled."""
    import bmesh as _bm, random as _r, mathutils as _mu
    V = _mu.Vector
    rng = _r.Random(seed)
    acc = {}
    def bm_for(m):
        if m.name not in acc: acc[m.name] = (_bm.new(), m)
        return acc[m.name][0]
    def place(bm, centre, normal, spin, size, cylinder=False):
        q = normal.to_track_quat("Z", "Y") @ _mu.Quaternion(V((0, 0, 1)), spin)
        mat = _mu.Matrix.Translation(centre) @ q.to_matrix().to_4x4()
        if cylinder:
            r = _bm.ops.create_cone(bm, cap_ends=True, segments=8, radius1=size[0], radius2=size[0], depth=size[2])
            _bm.ops.transform(bm, matrix=mat @ _mu.Matrix.Translation((0, 0, size[2] / 2)), verts=r["verts"])
        else:
            r = _bm.ops.create_cube(bm, size=1.0)
            sc = _mu.Matrix.Diagonal((size[0], size[1], size[2], 1))
            _bm.ops.transform(bm, matrix=mat @ _mu.Matrix.Translation((0, 0, size[2] / 2)) @ sc, verts=r["verts"])
    n_ = 0
    for o in objs:
        if o.type != "MESH": continue
        ms = [sl.material for sl in o.material_slots if sl.material]
        if not ms or ms[0] not in mats: continue
        mw = o.matrix_world; rot = mw.to_quaternion()
        for f in o.data.polygons:
            vs = [mw @ o.data.vertices[i].co for i in f.vertices]
            n = (rot @ f.normal).normalized()
            if n.z < -0.2 or n.y > 0.5 or len(vs) < 3: continue      # (not the faces the camera cannot see)
            area = sum(((vs[i] - vs[0]).cross(vs[i + 1] - vs[0])).length / 2 for i in range(1, len(vs) - 1))
            if area < 0.12: continue
            c = sum(vs, V((0, 0, 0))) / len(vs)
            for _ in range(max(1, int(area * density))):
                t = [rng.random() for _ in vs]; tot = sum(t)
                p0 = c + (sum((v * (w / tot) for v, w in zip(vs, t)), V((0, 0, 0))) - c) * 0.8
                spin = rng.choice((0, math.pi / 2)); kind = rng.random()
                if kind < 0.35:
                    place(bm_for(dark), p0, n, spin, (rng.uniform(0.08, 0.2), rng.uniform(0.06, 0.14), rng.uniform(0.03, 0.08)))
                elif kind < 0.55:
                    w, h = rng.uniform(0.14, 0.26), rng.uniform(0.1, 0.18)
                    place(bm_for(dark), p0, n, spin, (w, h, 0.015))
                    for s_ in (-1, 0, 1):
                        off = (n.to_track_quat("Z", "Y") @ _mu.Quaternion(V((0, 0, 1)), spin)) @ V((0, s_ * h * 0.28, 0))
                        place(bm_for(metal), p0 + off + n * 0.015, n, spin, (w * 0.85, h * 0.12, 0.012))
                elif kind < 0.75:
                    place(bm_for(metal), p0, n, spin, (rng.uniform(0.12, 0.3), rng.uniform(0.12, 0.3), 0.012))
                else:
                    for b_ in range(4):
                        a = b_ * math.pi / 2 + spin
                        place(bm_for(metal), p0 + (n.to_track_quat("Z", "Y") @ V((math.cos(a) * 0.06, math.sin(a) * 0.06, 0))),
                              n, 0, (0.018, 0, 0.02), cylinder=True)
                n_ += 1
    out = []
    for name, (bm, m) in acc.items():
        me = bpy.data.meshes.new("scatter-" + name); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new("scatter-" + name, me); scene.collection.objects.link(o); me.materials.append(m); out.append(o)
    print("scattered", n_, "parts")
    return out


def fabricator_kh():
    """A sealed fab module: a chamfered blue-grey block on a dark plinth, its sides ribbed; on its deck the fab drum, a
    ring of print heads turning on its crown (the working animation); a machine at each corner: the drive motor and its
    gearbox north-east, the coolant pair north-west, the control cabinet's screens south-west, the power box south-east;
    the loading bay south under a hazard band, its rollers out; the props a crew bolts on."""
    def build():
        octa(1.52, 0.14, 0, 0, 0, P["dark"])
        octa(1.43, 0.55, 0, 0.02, 0.14, P["hull"], sy=0.96)
        octa(1.45, 0.06, 0, 0.02, 0.69, P["dark"], sy=0.96)
        for k in range(16):                                                         # ribs round its sides
            a = (k + 0.5) * 2 * math.pi / 16
            x, y = math.cos(a) * 1.39, math.sin(a) * 1.39 * 0.96
            if y < -1.1 and abs(x) < 0.7: continue                                  # (not across the bay)
            o = B(0.06, 0.06, 0.5, x, y + 0.02, 0.17, P["trim"], bevel=0.01); o.rotation_euler = (0, 0, a)
        # The fab drum: a trim ring, the drum, its dark crown, the glass band round it lit within.
        cyl(0.78, 0.08, 0, 0.12, 0.75, P["trim"], verts=48)
        cyl(0.7, 0.42, 0, 0.12, 0.83, P["hull"], verts=48)
        cyl(0.71, 0.1, 0, 0.12, 1.0, P["glass"], verts=48)
        cyl(0.66, 0.05, 0, 0.12, 1.25, P["dark"], verts=48)
        for k in range(12):
            a = k * 2 * math.pi / 12
            o = B(0.05, 0.08, 0.42, math.cos(a) * 0.7, 0.12 + math.sin(a) * 0.7, 0.83, P["trim"], bevel=0.005); o.rotation_euler = (0, 0, a)
        cyl(0.2, 0.25, 0, 0.12, 1.3, P["steel"], verts=24)                         # the crown's hub
        # North-east: the drive motor along y and its gearbox, its shaft into the drum.
        B(0.55, 0.75, 0.1, 1.0, 0.65, 0.75, P["dark"])
        motor(1.02, 0.6, 0.85, 0.17, 0.62, P["hull"], P["steel"], axis="y")
        B(0.32, 0.3, 0.3, 0.98, 0.1, 0.85, P["trim"])
        lie(0.05, 0.35, 0.65, 0.15, 1.0, P["steel"], "x")
        # North-west: the coolant pair, banded, and their manifold into the drum.
        for y in (0.85, 0.4):
            cyl(0.2, 0.7, -1.05, y, 0.75, P["trim"], verts=24)
            for z in (0.9, 1.2):
                tor(0.2, 0.025, -1.05, y, z, P["dark"])
            cyl(0.09, 0.06, -1.05, y, 1.45, P["steel"], verts=16)
        pipe([(-1.05, 0.85, 1.5), (-0.85, 0.62, 1.58), (-0.55, 0.45, 1.2)], 0.045, P["steel"], P["dark"])
        pipe([(-1.05, 0.4, 1.5), (-0.82, 0.25, 1.4), (-0.7, 0.1, 1.05)], 0.04, P["steel"], P["dark"])
        # South-west: the control cabinet, its screens lit.
        B(0.55, 0.4, 0.55, -0.95, -0.7, 0.75, P["hull"])
        for k in range(2):
            B(0.2, 0.02, 0.16, -1.07 + k * 0.24, -0.91, 0.95, P["light"])
        B(0.5, 0.03, 0.05, -0.95, -0.92, 0.82, P["dark"])
        for k in range(4):
            cyl(0.025, 0.03, -1.15 + k * 0.12, -0.92, 0.78, P["accent"], verts=8, rot=(math.pi / 2, 0, 0))
        # South-east: the power box and its cables into the deck.
        B(0.45, 0.35, 0.42, 0.98, -0.72, 0.75, P["trim"])
        for k in range(3):
            rod((0.85 + k * 0.1, -0.55, 1.1), (0.55 + k * 0.08, -0.2, 0.8), 0.025, P["rubber"])
        B(0.3, 0.02, 0.18, 0.98, -0.9, 0.95, P["dark"])
        # The loading bay south.
        B(1.2, 0.12, 0.42, 0, -1.36, 0.14, P["dark"])
        B(1.0, 0.03, 0.34, 0, -1.43, 0.18, P["rubber"])
        for k in range(7):
            B(0.15, 0.04, 0.06, -0.52 + k * 0.173, -1.44, 0.6, P["accent"] if k % 2 == 0 else P["dark"])
        for k in range(4):
            lie(0.035, 0.95, 0, -1.5 - k * 0.08, 0.22, P["steel"], "x", 10)
        B(1.0, 0.36, 0.04, 0, -1.6, 0.14, P["dark"])
        for x in (-0.72, 0.72):
            B(0.1, 0.05, 0.1, x, -1.4, 0.4, P["light"])
        # A status mast north-east, a cable tray north, pipe stubs.
        cyl(0.045, 0.6, 1.2, 1.05, 0.75, P["dark"], verts=12)
        for k in range(3):
            cyl(0.07, 0.06, 1.2, 1.05, 1.12 + k * 0.1, P["light"], verts=16)
        B(2.0, 0.14, 0.06, 0, 1.3, 0.7, P["steel"])
        for x in (-0.5, 0.5):
            lie(0.1, 0.2, x, 1.46, 0.38, P["steel"], "y")
        prop("power_box_01_box", "power_box_01", (1.42, -0.2, 0.3), -90, 0.5)
        prop("utility_box_02", "utility_box_02", (-1.4, -0.2, 0.14), 90, 0.3)
    def build_heads():
        for k in range(6):
            a = k * 2 * math.pi / 6
            x, y = math.cos(a) * 0.45, 0.12 + math.sin(a) * 0.45
            B(0.1, 0.32, 0.06, x * 0.55, 0.12 + (y - 0.12) * 0.55, 1.34, P["steel"], rot=a + math.pi / 2, bevel=0.005)
            B(0.12, 0.12, 0.12, x, y, 1.3, P["dark"], rot=a, bevel=0.01)
            cyl(0.03, 0.05, x, y, 1.42, P["light"], verts=8)
    model = group(build)
    heads = group(build_heads)
    bpy.ops.object.empty_add(location=(0, 0.12, 1.3)); pv = bpy.context.object
    for o in heads:
        o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 1, density=10.0)
    def set_frame(f, frames):
        t = f / frames
        pv.rotation_euler = (0, 0, t * math.pi / 3)                                 # (six heads: a sixth of a turn loops)
        lpkit.emission(P["light"], 3.0 if (f % 4) < 2 else 1.5)
        lpkit.emission(P["glass"], 1.2 + 0.6 * math.sin(t * 2 * math.pi))
        bpy.context.view_layer.update()
    return model + heads, set_frame


def fabricator_gs():
    """An open scrap press: a welded girder frame on skids, its ram stamping onto the die and its flywheel turning (the
    working animation), a hopper over it, an old compressor and a gas bottle bolted on, hoses, patched plates, a crate of
    stock, an exhaust stack, an amber lamp on a pole."""
    def build():
        for sy in (-1, 1):
            B(2.9, 0.3, 0.16, 0, sy * 1.1, 0.0, P["dark"])
        B(2.6, 2.4, 0.12, 0, 0, 0.14, P["trim"])
        for x in (-0.6, 0.6):
            for y in (-0.3, 0.5):
                B(0.2, 0.2, 1.25, x, y, 0.26, P["hull"])
                for z in (0.5, 0.9):
                    B(0.22, 0.22, 0.05, x, y, z, P["dark"], bevel=0.005)
        # The crown: two girders across, east-west, the ram's cylinder between them (open: the ram shows from above).
        for y in (-0.3, 0.5):
            B(1.5, 0.22, 0.26, 0, y, 1.5, P["hull"])
            B(1.52, 0.24, 0.04, 0, y, 1.76, P["dark"], bevel=0.005)
        B(0.5, 0.6, 0.12, 0, 0.1, 1.62, P["hull"])
        B(0.95, 0.7, 0.2, 0, 0.1, 0.26, P["steel"])
        B(0.75, 0.5, 0.06, 0, 0.1, 0.46, P["dark"])
        cyl(0.17, 0.42, 0, 0.1, 1.76, P["dark"], verts=16)
        tor(0.17, 0.03, 0, 0.1, 2.0, P["steel"])
        # The hopper: a rusted funnel on legs over the press's north-west, scrap heaped in it, its chute down.
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.16, radius2=0.42, depth=0.4, location=(-0.55, 0.75, 1.95),
                                        rotation=(0, 0, math.pi / 4), end_fill_type="NOTHING")
        o = bpy.context.object; o.data.materials.append(P["trim"])
        o.modifiers.new("t", "SOLIDIFY").thickness = 0.03
        import random as _r
        rr = _r.Random(7)
        for k in range(14):
            B(rr.uniform(0.05, 0.13), rr.uniform(0.05, 0.13), rr.uniform(0.03, 0.08), -0.55 + rr.uniform(-0.22, 0.22),
              0.75 + rr.uniform(-0.22, 0.22), 2.02 + rr.uniform(0, 0.06), rr.choice((P["steel"], P["dark"], P["accent"])),
              rot=rr.uniform(0, 3), bevel=0.005)
        for dx in (-0.25, 0.25):
            rod((-0.55 + dx, 0.75 + 0.25, 1.75), (-0.55 + dx, 0.95, 0.26), 0.025, P["steel"])
        rod((-0.55, 0.75, 1.75), (-0.25, 0.35, 1.25), 0.05, P["steel"])
        # Scrap heaped on the bed by the die, stock for it.
        for k in range(16):
            B(rr.uniform(0.06, 0.16), rr.uniform(0.06, 0.16), rr.uniform(0.03, 0.09), 0.2 + rr.uniform(-0.3, 0.6),
              -0.78 + rr.uniform(-0.2, 0.15), 0.26, rr.choice((P["steel"], P["dark"], P["accent"], P["trim"])), rot=rr.uniform(0, 3), bevel=0.005)
        # The drive east: the flywheel's axle stands, its belt to the crown.
        B(0.3, 0.5, 0.7, 1.05, 0.3, 0.26, P["hull"])
        lie(0.05, 0.4, FX, FY + 0.2, FZ, P["steel"], "y", 10)
        rod((1.0, 0.1, 1.2), (0.7, 0.1, 1.62), 0.025, P["rubber"]); rod((1.0, 0.5, 1.2), (0.7, 0.5, 1.62), 0.025, P["rubber"])
        # Plates welded askew, rivet rows on them, a crate of stock, the stack, the lamp pole.
        for x, y, z, r, w, h in ((-0.95, -0.42, 0.45, 8, 0.5, 0.55), (0.92, -0.25, 0.4, -10, 0.45, 0.45),
                                 (-0.3, -0.42, 1.52, 4, 0.55, 0.24), (0.25, 0.65, 1.62, -6, 0.5, 0.06)):
            o = B(w, 0.06 if h > 0.1 else 0.5, h if h > 0.1 else 0.06, x, y, z, P["accent"] if r < 0 else P["trim"], bevel=0.01)
            o.rotation_euler = (0, math.radians(r), 0)
        B(0.72, 0.58, 0.42, -0.85, -0.85, 0.26, P["trim"])
        for k in range(3):
            B(0.6, 0.07, 0.05, -0.85, -0.85 + (k - 1) * 0.17, 0.69, P["steel"])
        for k in range(4):
            lie(0.04, 0.6, -0.85, -1.0 + k * 0.1, 0.72 + (k % 2) * 0.05, P["steel"], "x", 8)
        cyl(0.1, 1.45, 1.15, 0.95, 0.26, P["dark"], verts=12)
        tor(0.11, 0.03, 1.15, 0.95, 1.7, P["steel"])
        cyl(0.12, 0.1, 1.15, 0.95, 1.72, P["rubber"], verts=12)
        rod((-1.22, 0.98, 0.26), (-1.22, 0.98, 1.75), 0.03, P["steel"])
        rod((-1.22, 0.98, 1.75), (-1.0, 0.98, 1.8), 0.02, P["steel"])
        sph(0.08, -1.0, 0.98, 1.8, P["light"])
        pipe([(0.15, 0.4, 1.9), (0.6, 0.9, 1.4), (0.95, 0.95, 0.65)], 0.03, P["rubber"])
        pipe([(-0.15, 0.4, 1.85), (-0.7, 0.95, 1.2), (-0.95, 0.85, 0.55)], 0.03, P["rubber"])
        prop("old_military_compressor", "old_military_compressor", (0.9, 0.95, 0.26), 180, 0.3)
        prop("small_lpg_tank", "small_lpg_tank", (-1.05, 0.55, 0.26), 30, 0.45)
        prop("utility_box_01", "utility_box_01", (-1.3, -0.1, 0.4), 90, 0.35)
        prop("pipe_valve_small_1_metal", "modular_pipes", (-0.65, 0.95, 0.4), 0, 0.5)
    def build_ram():
        B(0.68, 0.48, 0.48, 0, 0.1, 0.92, P["steel"])
        B(0.7, 0.5, 0.06, 0, 0.1, 1.38, P["dark"])
        cyl(0.08, 0.5, 0, 0.1, 1.3, P["steel"], verts=12)
        B(0.64, 0.04, 0.05, 0, -0.15, 1.05, P["light"])
    # The flywheel: on the press's east face, toward the camera, its spokes turning while it works.
    FX, FY, FZ = 1.12, -0.12, 0.78
    def build_fly():
        lie(0.3, 0.05, FX, FY, FZ, P["dark"], "y", 32)
        for k in range(4):
            a = k * math.pi / 4
            o = B(0.56, 0.04, 0.04, FX, FY - 0.04, FZ - 0.02, P["steel"], bevel=0.0); o.rotation_euler = (0, a, 0)
            o.location = (FX, FY - 0.04, FZ)
        t_ = tor(0.3, 0.035, FX, FY - 0.02, FZ, P["steel"]); t_.rotation_euler = (math.pi / 2, 0, 0)
        lie(0.06, 0.1, FX, FY - 0.06, FZ, P["accent"], "y", 12)
    model = group(build)
    ram = group(build_ram); fly = group(build_fly)
    bpy.ops.object.empty_add(location=(0, 0.1, 0.92)); pv = bpy.context.object
    for o in ram:
        o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    bpy.ops.object.empty_add(location=(FX, FY, FZ)); fv = bpy.context.object
    for o in fly:
        o.parent = fv; o.matrix_parent_inverse = fv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 2, density=10.0)
    def set_frame(f, frames):
        t = f / frames
        d = 1.0 - min(1.0, t / 0.2) if t < 0.2 else (0.0 if t < 0.35 else (t - 0.35) / 0.65)
        pv.location.z = 0.92 - 0.38 * (1.0 - d)
        fv.rotation_euler = (0, t * math.pi / 4, 0)          # (eight spoke ends: an eighth of a turn loops)
        lpkit.emission(P["light"], 4.0 if 0.18 < t < 0.4 else 1.0)
        bpy.context.view_layer.update()
    return model + ram + fly, set_frame


def generator_kh():
    """A fusion cell: a squat reactor vessel on a dark pad, a lit ring of its core showing through a band of glass, its
    coolant fins round it, two terminal posts to the grid with their insulators, a pump and its pipe loop, a status lamp;
    the core's glow pulses and a ring of vanes turns on its crown (always: it runs while the camp stands)."""
    def build():
        B(1.85, 1.85, 0.12, 0, 0, 0, P["dark"])
        octa(0.95, 0.16, 0, 0.05, 0.12, P["trim"])
        cyl(0.66, 0.38, 0, 0.05, 0.28, P["hull"], verts=48)
        cyl(0.67, 0.1, 0, 0.05, 0.42, P["glass"], verts=48)
        cyl(0.6, 0.18, 0, 0.05, 0.66, P["hull"], verts=48)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.58, location=(0, 0.05, 0.84), segments=48, ring_count=24)
        o = bpy.context.object; o.scale = (1, 1, 0.42); o.data.materials.append(P["trim"])
        cyl(0.18, 0.12, 0, 0.05, 1.04, P["dark"], verts=24)
        for k in range(16):
            a = k * 2 * math.pi / 16
            o = B(0.04, 0.16, 0.42, math.cos(a) * 0.7, 0.05 + math.sin(a) * 0.7, 0.28, P["steel"], bevel=0.005)
            o.rotation_euler = (0, 0, a)
        # Terminal posts north-east and north-west, insulator stacks, the cable from each down into the vessel.
        for sx in (-1, 1):
            x, y = sx * 0.72, 0.72
            B(0.18, 0.18, 0.4, x, y, 0.12, P["dark"])
            for k in range(4):
                cyl(0.06 - k * 0.005, 0.05, x, y, 0.55 + k * 0.07, P["trim"], verts=12)
            sph(0.05, x, y, 0.85, P["steel"])
            rod((x, y, 0.5), (sx * 0.4, 0.4, 0.6), 0.025, P["rubber"])
        # A pump south-east and its coolant loop round to the vessel; a lamp and a gauge south-west.
        B(0.32, 0.26, 0.26, 0.62, -0.62, 0.12, P["hull"])
        motor(0.62, -0.62, 0.38, 0.09, 0.3, P["trim"], P["steel"], axis="x")
        pipe([(0.62, -0.5, 0.3), (0.45, -0.3, 0.32), (0.3, -0.45, 0.45)], 0.035, P["steel"], P["dark"])
        cyl(0.04, 0.35, -0.72, -0.7, 0.12, P["dark"], verts=10)
        cyl(0.06, 0.06, -0.72, -0.7, 0.47, P["light"], verts=12)
        gauge(-0.4, -0.62, 0.36, P["dark"], P["trim"])
        for k in range(5):
            B(0.18, 0.04, 0.05, -0.36 + k * 0.18, -0.9, 0.12, P["accent"] if k % 2 == 0 else P["dark"])
        prop("power_box_01_box", "power_box_01", (-0.82, 0.0, 0.12), 90, 0.35)
    def build_vanes():
        for k in range(8):
            a = k * 2 * math.pi / 8
            o = B(0.26, 0.05, 0.03, math.cos(a) * 0.3, 0.05 + math.sin(a) * 0.3, 1.0, P["steel"], rot=a, bevel=0.0)
    model = group(build)
    vanes = group(build_vanes)
    bpy.ops.object.empty_add(location=(0, 0.05, 1.0)); pv = bpy.context.object
    for o in vanes:
        o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 3, density=10.0)
    def set_frame(f, frames):
        t = f / frames
        pv.rotation_euler = (0, 0, t * math.pi / 4)
        lpkit.emission(P["glass"], 2.0 + 1.0 * math.sin(t * 2 * math.pi))
        lpkit.emission(P["light"], 3.0 if (f % 8) < 4 else 1.0)
        bpy.context.view_layer.update()
    return model + vanes, set_frame


def generator_gs():
    """A scrap genset: an engine block on skids, its radiator grille south with the fan turning behind it, a flywheel
    and belt to the dynamo, an exhaust stack, fuel drums lashed on, a cable reel, an amber lamp."""
    import random as _r
    rr = _r.Random(11)
    def build():
        for sx in (-1, 1):
            B(1.8, 0.22, 0.12, 0, sx * 0.7, 0, P["dark"])
        B(1.7, 1.55, 0.08, 0, 0, 0.12, P["trim"])
        # The engine block: ochre, its cylinder heads, the exhaust manifold.
        B(0.9, 0.9, 0.5, -0.15, 0.15, 0.2, P["hull"])
        for k in range(4):
            B(0.18, 0.7, 0.12, -0.5 + k * 0.23, 0.15, 0.7, P["hull"] if k % 2 else P["trim"], bevel=0.01)
            cyl(0.03, 0.05, -0.5 + k * 0.23, -0.15, 0.82, P["dark"], verts=8)
        pipe([(-0.5, 0.55, 0.75), (-0.5, 0.62, 0.9), (0.6, 0.62, 0.95)], 0.05, P["dark"], P["steel"])
        cyl(0.09, 0.9, 0.6, 0.62, 0.2, P["dark"], verts=12)
        cyl(0.11, 0.08, 0.6, 0.62, 1.1, P["rubber"], verts=12)
        # The radiator south: a frame, its grille, the fan behind it.
        B(0.9, 0.12, 0.6, -0.15, -0.42, 0.2, P["hull"])
        for k in range(8):
            B(0.75, 0.02, 0.03, -0.15, -0.49, 0.26 + k * 0.06, P["dark"], bevel=0.0)
        # The dynamo east, its flywheel and belt.
        lie(0.2, 0.5, 0.55, -0.05, 0.42, P["trim"], "x", 24)
        for k in range(6):
            lie(0.205, 0.03, 0.35 + k * 0.08, -0.05, 0.42, P["dark"], "x", 24)
        rod((0.32, -0.05, 0.62), (-0.55, -0.05, 0.62), 0.02, P["rubber"])
        # Fuel drums lashed on north-east, a cable reel south-east, scrap plates welded on.
        for k, (x, y) in enumerate(((0.55, 0.15), (0.75, 0.38))):
            cyl(0.15, 0.4, x, y + 0.05, 0.2, P["accent"] if k else P["steel"], verts=20)
            tor(0.15, 0.015, x, y + 0.05, 0.35, P["dark"])
        lie(0.18, 0.12, 0.6, -0.55, 0.3, P["dark"], "x", 20)
        lie(0.13, 0.13, 0.6, -0.55, 0.3, P["rubber"], "x", 20)
        for x, y, z, r in ((-0.6, -0.2, 0.3, 6), (0.2, 0.62, 0.3, -8)):
            o = B(0.3, 0.05, 0.25, x, y, z, P["trim"], bevel=0.01); o.rotation_euler = (0, math.radians(r), 0)
        rod((-0.75, 0.6, 0.2), (-0.75, 0.6, 1.2), 0.025, P["steel"])
        sph(0.06, -0.75, 0.6, 1.24, P["light"])
        for k in range(8):
            B(rr.uniform(0.05, 0.12), rr.uniform(0.05, 0.12), rr.uniform(0.03, 0.07), rr.uniform(-0.8, -0.3),
              rr.uniform(-0.75, -0.55), 0.2, rr.choice((P["steel"], P["dark"], P["accent"])), rot=rr.uniform(0, 3), bevel=0.005)
        prop("small_lpg_tank", "small_lpg_tank", (-0.72, 0.1, 0.2), 0, 0.3)
    FX, FY, FZ = -0.15, -0.35, 0.5
    def build_fan():
        for k in range(4):
            o = B(0.55, 0.03, 0.09, FX, FY, FZ - 0.045, P["steel"], bevel=0.0); o.rotation_euler = (0, k * math.pi / 4, 0)
            o.location = (FX, FY, FZ)
    model = group(build)
    fan = group(build_fan)
    bpy.ops.object.empty_add(location=(FX, FY, FZ)); fv = bpy.context.object
    for o in fan:
        o.parent = fv; o.matrix_parent_inverse = fv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 4, density=9.0)
    def set_frame(f, frames):
        t = f / frames
        fv.rotation_euler = (0, t * math.pi / 4, 0)
        lpkit.emission(P["light"], 3.5 if (f % 8) < 4 else 1.0)
        bpy.context.view_layer.update()
    return model + fan, set_frame


def radar_kh():
    """A phased-array mast: a square plinth, a tapered blue-grey tower with a ribbed service cabinet, a turntable on its
    top and the array on it, a dark panel gridded with cyan emitters, two aerials behind; the whole head turns (a radar's
    sprite turns through its directions), its emitters sweeping."""
    def build():
        B(2.2, 2.2, 0.14, 0, 0, 0, P["dark"])
        octa(1.0, 0.2, 0, 0, 0.14, P["trim"])
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.72, radius2=0.42, depth=1.2, location=(0, 0, 0.94),
                                        rotation=(0, 0, math.pi / 8))
        bpy.context.object.data.materials.append(P["hull"])
        for k in range(8):
            a = (k + 0.5) * 2 * math.pi / 8
            rod((math.cos(a) * 0.66, math.sin(a) * 0.66, 0.36), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.5), 0.025, P["trim"])
        B(0.5, 0.3, 0.55, 0.0, -0.75, 0.14, P["hull"])
        for k in range(4):
            B(0.4, 0.03, 0.04, 0.0, -0.91, 0.25 + k * 0.1, P["dark"], bevel=0.0)
        B(0.16, 0.03, 0.08, 0.0, -0.91, 0.62, P["light"])
        for sx in (-1, 1):
            B(0.35, 0.35, 0.3, sx * 0.8, -0.65, 0.14, P["trim"])
            lie(0.05, 0.5, sx * 0.6, -0.4, 0.3, P["steel"], "y")
        cyl(0.46, 0.1, 0, 0, 1.54, P["dark"], verts=32)
        prop("power_box_01_box", "power_box_01", (0.9, 0.35, 0.14), -90, 0.35)
    def build_head():
        cyl(0.36, 0.12, 0, 0, 1.64, P["steel"], verts=32)
        B(0.3, 0.3, 0.35, 0, 0, 1.76, P["hull"])
        # The array: a dark panel tilted back, gridded, framed; its back braced.
        arr = []
        o = B(1.5, 0.08, 0.9, 0, 0, 0, P["dark"], bevel=0.01); arr.append(o)
        for k in range(6):
            for j in range(4):
                arr.append(B(0.16, 0.02, 0.12, -0.6 + k * 0.24, -0.05, 0.12 + j * 0.2, P["glass"], bevel=0.0))
        for x in (-0.76, 0.76):
            arr.append(B(0.05, 0.1, 0.94, x, 0, -0.02, P["trim"], bevel=0.005))
        for z in (-0.02, 0.9):
            arr.append(B(1.56, 0.1, 0.05, 0, 0, z, P["trim"], bevel=0.005))
        bpy.ops.object.empty_add(location=(0, 0, 0)); g = bpy.context.object
        for o in arr:
            o.parent = g
        g.location = (0, -0.1, 1.95); g.rotation_euler = (math.radians(-20), 0, 0)
        rod((0, 0.05, 2.0), (0, 0.35, 2.6), 0.03, P["steel"])
        for sx in (-1, 1):
            rod((sx * 0.12, 0.15, 2.05), (sx * 0.12, 0.2, 2.75), 0.012, P["steel"])
            sph(0.03, sx * 0.12, 0.2, 2.77, P["light"])
    model = group(build)
    head = group(build_head)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 5, density=8.0)
    def set_frame(f, frames):
        pv.rotation_euler = (0, 0, f * 2 * math.pi / frames)
        lpkit.emission(P["light"], 2.0 + 1.2 * math.sin(f * 2 * math.pi / 8))
        lpkit.emission(P["glass"], 0.5 + 0.3 * math.sin(f * 2 * math.pi / 8))
        bpy.context.view_layer.update()
    return model + head, set_frame


def radar_gs():
    """A scavenged dish: a scrap-plated hut on skids, a lattice tripod over it, a patched parabolic dish on a turntable,
    its feed horn on struts, a counterweight of scrap, an amber lamp; the dish and its yoke turn."""
    def build():
        for sx in (-1, 1):
            B(2.3, 0.26, 0.12, 0, sx * 0.85, 0, P["dark"])
        B(2.1, 2.0, 0.08, 0, 0, 0.12, P["trim"])
        B(1.0, 0.9, 0.6, -0.45, -0.35, 0.2, P["hull"])
        B(1.06, 0.96, 0.05, -0.45, -0.35, 0.8, P["trim"])
        B(0.3, 0.04, 0.4, -0.25, -0.81, 0.2, P["dark"])
        B(0.2, 0.04, 0.12, -0.7, -0.81, 0.5, P["glass"])
        for k, (x, y, z, r) in enumerate(((-0.9, -0.8, 0.3, 8), (0.05, -0.81, 0.45, -6))):
            o = B(0.35, 0.05, 0.3, x, y, z, P["trim"] if k else P["accent"], bevel=0.01); o.rotation_euler = (0, math.radians(r), 0)
        for a in (0, 2.1, 4.2):
            rod((0.35 + math.cos(a) * 0.75, 0.25 + math.sin(a) * 0.75, 0.2), (0.35, 0.25, 1.5), 0.04, P["steel"])
        for z in (0.6, 1.0):
            k = 1 - (z - 0.2) / 1.3
            tor(0.75 * k, 0.02, 0.35, 0.25, z, P["steel"])
        cyl(0.22, 0.12, 0.35, 0.25, 1.48, P["dark"], verts=24)
        for k in range(6):
            cyl(0.07, 0.2, 0.75 + (k % 3) * 0.16, -0.65 + (k // 3) * 0.16, 0.2, P["accent"] if k % 2 else P["steel"], verts=12)
        rod((-1.0, 0.8, 0.2), (-1.0, 0.8, 1.4), 0.025, P["steel"]); sph(0.06, -1.0, 0.8, 1.44, P["light"])
        prop("utility_box_01", "utility_box_01", (-1.05, 0.2, 0.2), 90, 0.32)
    def build_head():
        X, Y, Z = 0.35, 0.25, 1.6
        cyl(0.18, 0.1, X, Y, Z, P["steel"], verts=24)
        for sx in (-1, 1):
            B(0.06, 0.12, 0.45, X + sx * 0.25, Y, Z + 0.05, P["hull"], bevel=0.005)
        # The dish: a bowl (a sphere's cap) opening south and up (n), its rim, ribs on its back, its feed horn on three
        # struts at its focus. (First turned the other way: its back faced the camera and read as a ball.)
        import mathutils as _mu
        R, CUT = 0.95, -0.6
        n = _mu.Vector((0, -0.6, 0.8))
        cap = _mu.Vector((X, Y, Z + 0.45)); loc = cap + n * R
        bpy.ops.mesh.primitive_uv_sphere_add(radius=R, location=(0, 0, 0), segments=40, ring_count=20)
        d = bpy.context.object
        import bmesh as _bm
        bm = _bm.new(); bm.from_mesh(d.data)
        _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > CUT], context="VERTS")
        bm.to_mesh(d.data); bm.free()
        d.modifiers.new("t", "SOLIDIFY").thickness = 0.03
        d.data.materials.append(P["trim"])
        rot = _mu.Vector((0, 0, 1)).rotation_difference(n)
        d.rotation_mode = "QUATERNION"; d.rotation_quaternion = rot; d.location = loc
        rr = math.sqrt(R * R - CUT * CUT)
        rim = tor(rr, 0.03, *(loc + rot @ _mu.Vector((0, 0, CUT))), P["steel"])
        rim.rotation_mode = "QUATERNION"; rim.rotation_quaternion = rot
        horn = loc + rot @ _mu.Vector((0, 0, CUT)) + n * 0.55
        for a in (0.3, 2.4, 4.5):
            p_ = loc + rot @ _mu.Vector((math.cos(a) * rr, math.sin(a) * rr, CUT))
            rod(tuple(p_), tuple(horn), 0.012, P["steel"])
        sph(0.06, *horn, P["dark"])
        for a in (0.0, 1.05, 2.1, 3.15, 4.2, 5.25):                                  # patches welded on its face
            p_ = loc + rot @ _mu.Vector((math.cos(a) * rr * 0.55, math.sin(a) * rr * 0.55, -math.sqrt(R * R - (rr * 0.55) ** 2) + 0.03))
            if a in (1.05, 4.2):
                o = B(0.22, 0.2, 0.015, *p_, P["accent"] if a < 3 else P["hull"], bevel=0.0)
                o.rotation_mode = "QUATERNION"; o.rotation_quaternion = rot
        B(0.3, 0.3, 0.25, X, Y + 0.35, Z + 0.05, P["dark"])
    model = group(build)
    head = group(build_head)
    bpy.ops.object.empty_add(location=(0.35, 0.25, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 6, density=8.0)
    def set_frame(f, frames):
        pv.rotation_euler = (0, 0, f * 2 * math.pi / frames)
        lpkit.emission(P["light"], 3.0 if (f % 8) < 4 else 1.0)
        bpy.context.view_layer.update()
    return model + head, set_frame


def drill_kh():
    """A sealed bore unit: a chamfered blue-grey housing on a dark skirt, the bore tower at its middle and its collar
    turning while it mines (seen through a ring of glass), the ore chute out to the north (the game puts the ore there),
    its conveyor and lamps, a motor and a cable run on its flanks."""
    def build():
        octa(1.55, 0.12, 0, 0, 0, P["dark"])
        octa(1.45, 0.42, 0, 0, 0.12, P["hull"])
        octa(1.47, 0.05, 0, 0, 0.54, P["dark"])
        for k in range(16):
            a = (k + 0.5) * 2 * math.pi / 16
            x, y = math.cos(a) * 1.41, math.sin(a) * 1.41
            if y > 1.1 and abs(x) < 0.6: continue
            o = B(0.06, 0.06, 0.38, x, y, 0.15, P["trim"], bevel=0.01); o.rotation_euler = (0, 0, a)
        cyl(0.7, 0.08, 0, 0, 0.59, P["trim"], verts=40)
        cyl(0.6, 0.12, 0, 0, 0.67, P["glass"], verts=40)
        cyl(0.42, 0.75, 0, 0, 0.79, P["hull"], verts=32)
        for z in (0.95, 1.25):
            tor(0.43, 0.03, 0, 0, z, P["trim"])
        cyl(0.3, 0.12, 0, 0, 1.54, P["dark"], verts=24)
        cyl(0.12, 0.3, 0, 0, 1.66, P["steel"], verts=16)
        # The chute north and its conveyor out over the edge, its lamps.
        B(0.62, 0.7, 0.28, 0, 1.05, 0.59, P["trim"])
        B(0.5, 0.75, 0.06, 0, 1.15, 0.87, P["dark"])
        for k in range(5):
            lie(0.03, 0.46, 0, 1.0 + k * 0.12, 0.6, P["steel"], "x", 8)
        for sx in (-1, 1):
            B(0.08, 0.05, 0.08, sx * 0.36, 1.42, 0.62, P["light"], bevel=0.0)
        # A drive motor east, a cable run west to a power box, the hazard band south, a status mast.
        B(0.45, 0.6, 0.08, 1.0, -0.2, 0.59, P["dark"])
        motor(1.0, -0.2, 0.67, 0.15, 0.55, P["hull"], P["steel"], axis="y")
        lie(0.05, 0.5, 0.62, -0.2, 0.82, P["steel"], "x")
        B(0.4, 0.3, 0.36, -1.0, -0.55, 0.59, P["trim"])
        B(0.25, 0.02, 0.14, -1.0, -0.71, 0.75, P["light"])
        for k in range(3):
            rod((-0.85 + k * 0.05, -0.4, 0.95), (-0.42, -0.1 + k * 0.05, 1.0), 0.022, P["rubber"])
        for k in range(8):
            B(0.15, 0.04, 0.06, -0.6 + k * 0.17, -1.42, 0.45, P["accent"] if k % 2 == 0 else P["dark"])
        cyl(0.04, 0.55, -1.05, 0.95, 0.59, P["dark"], verts=10)
        for k in range(2):
            cyl(0.065, 0.06, -1.05, 0.95, 1.14 + k * 0.09, P["light"], verts=14)
        prop("power_box_01_box", "power_box_01", (-1.45, 0.1, 0.25), 90, 0.45)
    def build_collar():
        for k in range(8):
            a = k * 2 * math.pi / 8
            B(0.12, 0.16, 0.08, math.cos(a) * 0.55, math.sin(a) * 0.55, 0.69, P["steel"], rot=a, bevel=0.005)
        for k in range(4):
            a = k * math.pi / 2 + 0.3
            B(0.08, 0.24, 0.05, math.cos(a) * 0.5, math.sin(a) * 0.5, 1.4, P["dark"], rot=a, bevel=0.005)
    # The percussion ram (0.2.325; the user's rating, 2026-11-11: "a little more complicated ... a percussion from the
    # central pole rising up slowly and hitting the ground fast"): a guide frame of two columns over the bore tower, a
    # crosshead and its hydraulic lift cylinder, the ram a heavy hazard-banded block on the anvil, lifted slowly and let
    # fall.
    def build_frame():
        for sx in (-1, 1):
            B(0.09, 0.12, 1.55, sx * 0.4, 0, 1.6, P["dark"], bevel=0.01)
            B(0.16, 0.2, 0.08, sx * 0.4, 0, 1.6, P["trim"], bevel=0.01)
            rod((sx * 0.4, 0.0, 2.2), (sx * 0.4, 0.0, 1.66), 0.012, P["steel"])
        B(1.0, 0.24, 0.16, 0, 0, 3.15, P["hull"], bevel=0.02)
        B(1.02, 0.05, 0.04, 0, -0.12, 3.2, P["accent"], bevel=0.0)
        cyl(0.13, 0.5, 0, 0, 2.65, P["trim"], verts=16)                      # the lift cylinder, under the crosshead
        cyl(0.15, 0.05, 0, 0, 2.65, P["dark"], verts=16)
        for sx in (-1, 1):
            pipe([(sx * 0.12, 0.08, 3.05), (sx * 0.3, 0.15, 3.0), (sx * 0.45, 0.2, 2.0), (sx * 0.55, 0.3, 0.75)], 0.022, P["rubber"])
        cyl(0.09, 0.3, 0, 0, 1.66, P["steel"], verts=16)                      # the anvil, on the bore's spindle
        cyl(0.05, 0.06, 0.4, -0.08, 3.23, P["light"], verts=10)               # a beacon on the crosshead
    def build_ram():
        octa(0.26, 0.36, 0, 0, 1.96, P["gunmetal"])
        for z in (2.02, 2.2):
            octa(0.265, 0.06, 0, 0, z, P["accent"])
        cyl(0.06, 0.4, 0, 0, 2.32, P["steel"], verts=12)                      # the piston rod, up into the cylinder
        for sx in (-1, 1):
            B(0.14, 0.1, 0.12, sx * 0.3, 0, 2.1, P["dark"], bevel=0.01)       # the guide shoes on the columns
    model = group(build)
    collar = group(build_collar)
    model += group(build_frame)
    ram = group(build_ram)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in collar:
        o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    bpy.ops.object.empty_add(location=(0, 0, 0)); lift = bpy.context.object
    for o in ram:
        o.parent = lift; o.matrix_parent_inverse = lift.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 8, density=9.0)
    def ram_height(t):
        """Up slowly over three quarters of the cycle (eased), down in an eighth (falling), resting on the anvil after."""
        if t < 0.75:
            u = t / 0.75; return 0.55 * (u * u * (3 - 2 * u))
        if t < 0.875:
            u = (t - 0.75) / 0.125; return 0.55 * (1 - u * u)
        return 0.0
    def set_frame(f, frames):
        t = f / frames
        lift.location.z = ram_height(t)
        pv.rotation_euler = (0, 0, t * math.pi / 4)
        lpkit.emission(P["glass"], 0.45 + 0.25 * math.sin(t * 4 * math.pi))
        lpkit.emission(P["light"], 3.0 if (f % 4) < 2 else 1.2)
        bpy.context.view_layer.update()
    return model + collar + ram, set_frame


def pylon_kh():
    """A composite mast with the mass of vanilla's medium pole (the coordinator's review: the first was "a bare stick"):
    a plinth and its cable box, a tapered banded tubular mast braced at its foot, two crossarms, insulator strings
    hanging from each arm's ends and standing on its top (the copper wire on the top one, the circuit wires on the
    lower arm's), a cyan beacon."""
    import mathutils as _mu
    V = _mu.Vector
    def string(x, y, z, n=4):
        """An insulator string hanging from (x, y, z): its discs, its fitting; returns where the wire clamps."""
        rod((x, y, z), (x, y, z - 0.05), 0.012, P["steel"])
        for k in range(n):
            cyl(0.045, 0.025, x, y, z - 0.08 - k * 0.055, P["glass"], verts=12)
        sph(0.02, x, y, z - 0.12 - n * 0.055, P["steel"])
        return V((x, y, z - 0.12 - n * 0.055))
    tips = {}
    def build():
        B(0.42, 0.42, 0.12, 0, 0, 0, P["dark"], bevel=0.02)
        B(0.16, 0.08, 0.22, 0, -0.2, 0.12, P["hull"], bevel=0.01)
        B(0.06, 0.02, 0.04, 0, -0.245, 0.27, P["light"], bevel=0.0)
        # (Its mass: a mast this thick, a transformer can and a cable riser on it; first rendered at 0.15 it still
        # read as a stick beside vanilla's lattice tower.)
        # (Dark, its bands the corporation's blue and one hazard: in its blue hull it read "too bright! toy like", the
        # user's rating, 2026-11-10.)
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.22, radius2=0.1, depth=3.0, location=(0, 0, 1.62))
        bpy.context.object.data.materials.append(P["dark"])
        for a in (0.4, 2.5, 4.6):
            rod((math.cos(a) * 0.26, math.sin(a) * 0.26, 0.12), (0, 0, 0.75), 0.022, P["steel"])
        for z in (0.55, 1.15, 1.75, 2.35):
            cyl(0.2 - z * 0.035, 0.06, 0, 0, z, P["accent"] if z == 1.15 else P["hull"], verts=12)
        cyl(0.13, 0.42, 0.24, -0.06, 1.6, P["hull"], verts=16, bevel=0.02)
        for z in (1.68, 1.9):
            tor(0.13, 0.015, 0.24, -0.06, z, P["dark"])
        cyl(0.05, 0.08, 0.24, -0.06, 2.02, P["glass"], verts=10)
        B(0.12, 0.08, 0.1, 0.1, -0.06, 1.65, P["dark"], bevel=0.01)
        rod((0.0, -0.17, 0.25), (0.0, -0.1, 2.5), 0.025, P["rubber"])
        for z in (0.9, 1.3, 2.1):
            B(0.08, 0.06, 0.04, 0.0, -0.13, z, P["steel"], bevel=0.0)
        # The crossarms: the lower carries the circuit wires, the upper two more strings; braces under each.
        for z, w in ((2.55, 0.48), (2.9, 0.36)):
            B(2 * w + 0.14, 0.1, 0.1, 0, 0, z, P["dark"], bevel=0.015)
            for sx in (-1, 1):
                rod((sx * w * 0.7, 0, z), (0, 0, z - 0.3), 0.015, P["steel"])
        tips["red"] = string(-0.48, 0, 2.55)
        tips["green"] = string(0.48, 0, 2.55)
        string(-0.36, 0, 2.9, 3); string(0.36, 0, 2.9, 3)
        for k in range(4):                                          # the top insulator, standing; the copper on it
            cyl(0.05, 0.03, 0, 0, 3.12 + k * 0.05, P["glass"], verts=12)
        cyl(0.025, 0.06, 0, 0, 3.32, P["steel"], verts=8)
        tips["copper"] = V((0, 0, 3.36))
        rod((0.06, 0, 2.98), (0.16, 0, 3.15), 0.012, P["steel"])
        sph(0.04, 0.16, 0, 3.17, P["light"])
    model = group(build)
    return model, tips


def pylon_gs():
    """A scrap pole: a rail tie for a post, banded with wire, a crossbar of angle iron, glass insulators on pins, a
    lantern hung off it, a bucket of rocks for a foot."""
    import mathutils as _mu
    V = _mu.Vector
    def build():
        cyl(0.2, 0.22, 0, 0, 0, P["accent"], verts=12)
        tor(0.2, 0.02, 0, 0, 0.2, P["dark"])
        B(0.15, 0.13, 2.55, 0, 0, 0.1, P["trim"], bevel=0.01)
        for z in (0.6, 1.4):
            tor(0.11, 0.012, 0, 0, z, P["steel"])
        o = B(0.8, 0.06, 0.06, 0, 0.02, 2.35, P["steel"], bevel=0.0); o.rotation_euler.y = math.radians(4)
        rod((-0.25, 0.02, 2.36), (0, 0.02, 2.0), 0.015, P["steel"]); rod((0.25, 0.02, 2.38), (0, 0.02, 2.0), 0.015, P["steel"])
        for x in (-0.33, 0.0, 0.33):
            cyl(0.012, 0.1, x, 0.02, 2.41, P["steel"], verts=6)
            cyl(0.04, 0.07, x, 0.02, 2.48, P["glass"], verts=10)
        rod((0.33, 0.02, 2.38), (0.36, 0.02, 2.2), 0.008, P["steel"])
        cyl(0.04, 0.08, 0.36, 0.02, 2.1, P["dark"], verts=8)
        sph(0.035, 0.36, 0.02, 2.15, P["light"])
        for k in range(3):
            B(0.08, 0.06, 0.05, -0.08 + k * 0.08, 0.15, 0.1 + k * 0.03, P["dark"], rot=k, bevel=0.005)
    tips = {"copper": V((0, 0.02, 2.56)), "red": V((-0.33, 0.02, 2.56)), "green": V((0.33, 0.02, 2.56))}
    return group(build), tips


def pylon_gs_concept(name):
    """Grubstake's pole, three clay concepts (phase 2, its pylon; the KH mast's review: "a bare stick" is what to avoid):
    gs-a the scrap pole above; gs-b a welded pipe tripod, braced, a channel-iron crossarm; gs-c a steel I-beam stood in
    two welded oil drums, guyed, two angle-iron crossarms, a gas bottle for a transformer."""
    import mathutils as _mu
    V = _mu.Vector
    if name == "gs-a":
        return pylon_gs()
    tips = {}
    def b_build():
        # (Its mass: first rendered at legs of 0.035, 0.36 apart and 2.55 tall, it read light and short beside vanilla's
        # medium pole and the KH mast, its bays empty.)
        R, TOP = 0.46, 2.95
        legs = [(math.cos(a) * R, math.sin(a) * R) for a in (math.radians(90), math.radians(210), math.radians(330))]
        top = (0.0, 0.0, TOP)
        def at(i, z):
            k = 1 - z / (TOP + 0.35); x, y = legs[i]; return (x * k, y * k, z)
        # (Legs near black, a hazard band on each, its crossarm hazard yellow: in rust plate it went into the ground,
        # "more contrast, disappears against the ground", the user's rating, 2026-11-10.)
        for i, (x, y) in enumerate(legs):
            rod((x, y, 0.0), at(i, TOP), 0.05, P["dark"])
            for z0 in (0.75, 1.85):
                a0, a1 = at(i, z0), at(i, z0 + 0.16)
                rod(a0, a1, 0.058, P["hazard"])
            B(0.2, 0.2, 0.12, x, y, 0, P["dark"], bevel=0.015)                     # a block of concrete each foot
            B(0.12, 0.12, 0.03, x, y, 0.12, P["steel"], bevel=0.0)                  # its base plate
        zs = (0.12, 0.65, 1.2, 1.75, 2.3, TOP - 0.05)
        for z in zs[1:]:
            for i in range(3):
                rod(at(i, z), at((i + 1) % 3, z), 0.022, P["steel"])
        for j in range(len(zs) - 1):                                                # X braces in every bay
            z0, z1 = zs[j], zs[j + 1]
            for i in range(3):
                n = (i + 1) % 3
                rod(at(i, z0), at(n, z1), 0.013, P["steel"]); rod(at(n, z0), at(i, z1), 0.013, P["steel"])
        cz = TOP + 0.02
        B(1.15, 0.1, 0.12, 0, 0, cz, P["hazard"], bevel=0.012)                       # a channel-iron crossarm
        B(1.15, 0.03, 0.04, 0, 0.06, cz + 0.08, P["dark"], bevel=0.0)
        rod((-0.42, 0, cz), (0, 0, cz - 0.45), 0.018, P["steel"]); rod((0.42, 0, cz), (0, 0, cz - 0.45), 0.018, P["steel"])
        for x in (-0.5, 0.5):
            cyl(0.014, 0.08, x, 0, cz + 0.12, P["steel"], verts=6)
            for k in range(3): cyl(0.045 - k * 0.006, 0.03, x, 0, cz + 0.16 + k * 0.035, P["glass"], verts=10)
        for k in range(4): cyl(0.05 - k * 0.006, 0.035, 0, 0, cz + 0.14 + k * 0.04, P["glass"], verts=10)
        cyl(0.02, 0.05, 0, 0, cz + 0.3, P["steel"], verts=8)
        x0, y0 = legs[0]
        for k in range(11):                                                         # ladder rungs up one leg
            z = 0.25 + k * 0.24; px, py, _ = at(0, z)
            rod((px - 0.08, py, z), (px + 0.08, py, z), 0.009, P["steel"])
        px, py, _ = at(1, 1.0)
        o = B(0.24, 0.025, 0.2, px * 0.95, py * 0.95, 0.9, P["hull"], bevel=0.005)  # a patch plate welded on
        o.rotation_euler = (0, 0, math.radians(300))
        B(0.22, 0.15, 0.28, 0.14, -0.16, 1.0, P["accent"], bevel=0.012)              # a junction box on a leg
        B(0.14, 0.02, 0.1, 0.14, -0.24, 1.14, P["hazard"], bevel=0.0)
        rod((0.14, -0.16, 1.28), (0.02, 0, cz - 0.05), 0.014, P["rubber"])
        lie(0.16, 0.14, 0.42, -0.2, 0.16, P["dark"], "x", 20)                        # a cable reel beside a leg
        lie(0.11, 0.15, 0.42, -0.2, 0.16, P["rubber"], "x", 20)
        rod((-0.48, 0, cz), (-0.5, 0, cz - 0.2), 0.006, P["steel"])
        cyl(0.045, 0.09, -0.5, 0, cz - 0.32, P["dark"], verts=8); sph(0.04, -0.5, 0, cz - 0.26, P["light"])
        tips.update(copper=V((0, 0, cz + 0.33)), red=V((-0.5, 0, cz + 0.25)), green=V((0.5, 0, cz + 0.25)))
    def c_build():
        for k, z in enumerate((0.0, 0.42)):                                        # two oil drums, welded
            cyl(0.22, 0.42, 0, 0, z, P["accent"] if k else P["hull"], verts=20)
            for zz in (z + 0.12, z + 0.3): tor(0.22, 0.012, 0, 0, zz, P["dark"])
        cyl(0.2, 0.03, 0, 0, 0.84, P["dark"], verts=20)
        mast = B(0.09, 0.14, 2.2, 0, 0, 0.84, P["trim"], bevel=0.005)               # the I-beam
        mast.rotation_euler = (math.radians(2), math.radians(-1.5), 0)
        for x in (-0.06, 0.06): B(0.02, 0.16, 2.2, x, 0, 0.84, P["steel"], bevel=0.0).rotation_euler = mast.rotation_euler
        tz = 3.0
        for z, w in ((2.75, 0.5), (2.98, 0.34)):                                    # angle-iron crossarms
            o = B(2 * w + 0.1, 0.06, 0.06, 0.0, 0.0, z, P["steel"], bevel=0.0); o.rotation_euler.y = math.radians(3)
            for sx in (-1, 1): rod((sx * w * 0.8, 0, z), (0, 0, z - 0.28), 0.012, P["steel"])
        for x in (-0.5, 0.5):
            cyl(0.012, 0.08, x, 0, 2.81, P["steel"], verts=6)
            for k in range(3): cyl(0.05 - k * 0.006, 0.035, x, 0, 2.85 + k * 0.04, P["glass"], verts=10)
        for x in (-0.34, 0.34):
            cyl(0.04, 0.06, x, 0, 3.04, P["glass"], verts=10)
        for k in range(4): cyl(0.055 - k * 0.006, 0.04, 0, 0, tz + 0.05 + k * 0.045, P["glass"], verts=10)
        cyl(0.02, 0.05, 0, 0, tz + 0.24, P["steel"], verts=8)
        cyl(0.11, 0.5, 0.0, -0.18, 1.65, P["accent"], verts=16); sph(0.11, 0.0, -0.18, 2.15, P["accent"])
        for z in (1.72, 2.05): tor(0.12, 0.012, 0.0, -0.18, z, P["dark"])
        rod((0.0, -0.18, 2.25), (0.0, -0.05, 2.7), 0.012, P["rubber"])
        rod((0.0, 0.07, 2.3), (0.55, 0.65, 0.0), 0.006, P["steel"])                  # a guy wire to its stake
        cyl(0.025, 0.18, 0.55, 0.65, 0.0, P["dark"], verts=6)
        B(0.2, 0.02, 0.14, 0.0, -0.09, 1.25, P["hazard"], bevel=0.0)                 # a plate: danger
        rod((0.5, 0, 2.75), (0.52, 0, 2.55), 0.006, P["steel"])
        cyl(0.04, 0.08, 0.52, 0, 2.45, P["dark"], verts=8); sph(0.035, 0.52, 0, 2.5, P["light"])
        tips.update(copper=V((0, 0, tz + 0.27)), red=V((-0.5, 0, 2.97)), green=V((0.5, 0, 2.97)))
    model = group(b_build if name == "gs-b" else c_build)
    return model, tips


# --- Depots (4x4, the camp's store, where its army comes home and its cargo pods come down; Space Age's cargo landing
# pad at half size and tinted until now) and launchpads (9x9, its exports leave from it as a beam straight up; the
# tinted rocket silo until now). Static: a container's one picture. Two clay concepts a faction each, a: and b:.
def _still(fn):
    objs = group(fn)
    return objs, lambda f, n: None


def depot_kh_a():
    """A sealed landing pad: a chamfered deck on a plinth, a recessed landing ring lit cyan, four corner bollards with
    beacons, a cargo iris at its middle, a service crane on its north-east corner, a loading ramp south."""
    def build():
        octa(1.95, 0.14, 0, 0, 0, P["dark"], sx=1.0, sy=1.0)
        octa(1.8, 0.16, 0, 0, 0.14, P["hull"])
        tor(1.05, 0.06, 0, 0, 0.31, P["trim"]); tor(0.92, 0.03, 0, 0, 0.31, P["glass"])
        cyl(0.82, 0.04, 0, 0, 0.28, P["dark"], verts=48)
        for k in range(8):                                                    # the iris's leaves, shut
            a = k * math.pi / 4
            o = B(0.6, 0.3, 0.03, math.cos(a) * 0.35, math.sin(a) * 0.35, 0.31, P["dark"] if k % 2 else P["steel"], rot=a + 0.4,
                  bevel=0.005)   # (not hull or trim: scatter's parts had heaped on the leaves and the iris read as junk)
        cyl(0.14, 0.05, 0, 0, 0.33, P["steel"], verts=16)
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * 1.45, sy * 1.45
                octa(0.14, 0.45, x, y, 0.3, P["trim"]); cyl(0.07, 0.07, x, y, 0.75, P["light"], verts=12)
        for k in range(16):                                                   # chevrons on the deck round the ring
            a = k * 2 * math.pi / 16
            B(0.14, 0.05, 0.01, math.cos(a) * 1.3, math.sin(a) * 1.3, 0.3, P["accent"], rot=a, bevel=0.0)
        # The crane: a mast north-east, its boom over the deck, a hook block.
        cyl(0.13, 1.6, 1.35, 1.35, 0.3, P["trim"], verts=12)
        B(0.3, 0.3, 0.2, 1.35, 1.35, 1.9, P["hull"], bevel=0.02)
        rod((1.35, 1.35, 2.0), (0.2, 0.2, 2.15), 0.05, P["trim"])
        rod((0.2, 0.2, 2.15), (0.2, 0.2, 1.4), 0.008, P["steel"]); B(0.12, 0.12, 0.12, 0.2, 0.2, 1.3, P["dark"], bevel=0.01)
        B(0.9, 0.5, 0.12, 0, -2.0, 0.0, P["trim"], bevel=0.01)                   # a ramp south
        B(0.5, 0.3, 0.5, -1.4, 1.2, 0.3, P["hull"], bevel=0.03)                 # a control cabinet, its screen
        B(0.3, 0.02, 0.18, -1.4, 1.04, 0.6, P["glass"], bevel=0.0)
    return _still(build)


def depot_kh_b():
    """A pod catcher: a square cargo bay, low, its roof a receiving well; four guide towers at its corners hold a ring
    over the well (where a pod is caught), cyan lit; conduits down the towers, a hatch bay south."""
    def build():
        B(3.5, 3.5, 0.12, 0, 0, 0, P["dark"], bevel=0.03)
        B(3.2, 3.2, 0.5, 0, 0, 0.12, P["hull"], bevel=0.05)
        cyl(1.0, 0.06, 0, 0, 0.6, P["dark"], verts=48); tor(1.0, 0.07, 0, 0, 0.64, P["trim"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * 1.35, sy * 1.35
                B(0.32, 0.32, 1.9, x, y, 0.12, P["trim"], bevel=0.03)
                B(0.36, 0.36, 0.14, x, y, 2.0, P["hull"], bevel=0.02)
                cyl(0.06, 0.08, x, y, 2.14, P["light"], verts=12)
                rod((x, y, 2.0), (x * 0.6, y * 0.6, 2.0), 0.06, P["trim"])
                rod((x * 0.98, y * 0.98, 0.6), (x * 0.98, y * 0.98, 1.9), 0.02, P["rubber"])
        tor(1.15, 0.07, 0, 0, 2.0, P["trim"]); tor(1.15, 0.025, 0, 0, 2.06, P["glass"])
        B(1.2, 0.2, 0.42, 0, -1.65, 0.12, P["trim"], bevel=0.02)
        B(1.0, 0.02, 0.3, 0, -1.76, 0.16, P["accent"], bevel=0.0)
    return _still(build)


def depot_gs_a():
    """A scrap landing pad: a deck of welded plates on oil-drum stilts, its landing circle painted and worn, tyre
    bumpers at its corners, an A-frame hoist with its chain, crates and barrels stacked on the west side, a floodlight."""
    import random as _r
    rr = _r.Random(21)
    def build():
        for x in (-1.3, 0, 1.3):
            for y in (-1.3, 0, 1.3):
                cyl(0.18, 0.28, x, y, 0, P["accent"] if (x + y) % 2 else P["hull"], verts=14)
        for i in range(4):
            for j in range(4):
                o = B(0.86, 0.86, 0.06, -1.3 + i * 0.87, -1.3 + j * 0.87, 0.28 + rr.uniform(0, 0.02),
                      P["trim"] if (i + j) % 3 else P["hull"], bevel=0.005)
                o.rotation_euler = (rr.uniform(-0.01, 0.01), rr.uniform(-0.01, 0.01), rr.uniform(-0.03, 0.03))
        tor(0.95, 0.03, 0, 0, 0.35, P["hazard"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                tor(0.2, 0.08, sx * 1.6, sy * 1.6, 0.42, P["rubber"]); tor(0.2, 0.08, sx * 1.6, sy * 1.6, 0.56, P["rubber"])
        for sx in (-1, 1):                                                    # the A-frame hoist, east to west over the pad
            rod((sx * 1.5, 1.6, 0.3), (sx * 0.9, 1.6, 2.3), 0.05, P["trim"]); rod((sx * 1.5, 1.0, 0.3), (sx * 0.9, 1.6, 2.3), 0.04, P["trim"])
        rod((-0.9, 1.6, 2.3), (0.9, 1.6, 2.3), 0.06, P["hull"])
        rod((0.1, 1.6, 2.3), (0.1, 1.2, 1.1), 0.01, P["steel"]); B(0.15, 0.1, 0.18, 0.1, 1.2, 0.95, P["dark"], bevel=0.01)
        for k in range(6):                                                    # crates and barrels on the west side
            B(0.42, 0.42, 0.38, -1.55 + (k % 2) * 0.1, -1.0 + k * 0.32, 0.34, P["hull"] if k % 2 else P["trim"], rot=rr.uniform(-0.2, 0.2), bevel=0.02)
        for k in range(3): cyl(0.15, 0.4, -0.9, -1.55 + k * 0.32, 0.34, P["accent"], verts=16)
        rod((1.7, -1.7, 0.0), (1.7, -1.7, 2.0), 0.035, P["steel"])
        B(0.25, 0.12, 0.16, 1.62, -1.62, 2.0, P["dark"], bevel=0.01); B(0.2, 0.02, 0.1, 1.6, -1.55, 2.02, P["light"], bevel=0.0)
    return _still(build)


def depot_gs_b():
    """A catch pit: a ring wall of stacked tyres and scrap sheet round a sandbagged pit, a cargo net strung between four
    leaning poles over it, a hand winch, a lantern on a pole, a shack of patched sheet in the south-west corner."""
    import random as _r
    rr = _r.Random(22)
    def build():
        cyl(1.25, 0.06, 0, 0, 0, P["dark"], verts=40)
        for k in range(22):                                                   # the tyre ring, two high
            a = k * 2 * math.pi / 22
            for z in (0.1, 0.26):
                o = tor(0.2, 0.07, math.cos(a) * 1.45, math.sin(a) * 1.45, z, P["rubber"]); o.rotation_euler = (0, 0, a)
        for k in range(10):                                                   # scrap sheets leaning on it
            a = k * 2 * math.pi / 10 + rr.uniform(0, 0.3)
            o = B(0.5, 0.04, 0.5, math.cos(a) * 1.68, math.sin(a) * 1.68, 0.0, P["trim"] if k % 2 else P["hull"], rot=a + math.pi / 2, bevel=0.005)
            o.rotation_euler.x = math.radians(rr.uniform(-15, 15))
        tops = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                b = (sx * 1.7, sy * 1.7, 0.0); t = (sx * 1.35, sy * 1.35, 1.9)
                rod(b, t, 0.045, P["steel"]); tops.append(t)
        for i in range(4):
            for j in range(5):
                u = j / 4
                p0 = [tops[0][q] + (tops[1][q] - tops[0][q]) * u for q in range(3)]
                p1 = [tops[2][q] + (tops[3][q] - tops[2][q]) * u for q in range(3)]
                p0[2] -= 0.25 * math.sin(u * math.pi); p1[2] -= 0.25 * math.sin(u * math.pi)
                rod(tuple(p0), tuple(p1), 0.01, P["cloth"])
                q0 = [tops[0][q] + (tops[2][q] - tops[0][q]) * u for q in range(3)]
                q1 = [tops[1][q] + (tops[3][q] - tops[1][q]) * u for q in range(3)]
                q0[2] -= 0.25 * math.sin(u * math.pi); q1[2] -= 0.25 * math.sin(u * math.pi)
                rod(tuple(q0), tuple(q1), 0.01, P["cloth"])
        lie(0.12, 0.35, 1.2, -1.9, 0.35, P["dark"], "x", 16); B(0.3, 0.2, 0.3, 1.2, -1.9, 0.05, P["trim"], bevel=0.01)
        B(0.9, 0.8, 0.7, -1.45, -1.45, 0.0, P["hull"], bevel=0.02)
        o = B(1.0, 0.9, 0.05, -1.45, -1.45, 0.72, P["trim"], bevel=0.005); o.rotation_euler.x = math.radians(8)
        rod((1.85, 1.85, 0.0), (1.85, 1.85, 1.5), 0.025, P["steel"]); sph(0.06, 1.85, 1.85, 1.45, P["light"])
    return _still(build)


def launchpad_kh_a():
    """An electromagnetic launcher: an octagonal deck, at its middle a launch tube rising from a ring of capacitor banks,
    its mouth ringed with coils lit cyan (where the beam leaves), a gantry tower beside it with a swing arm to the tube,
    two spherical tanks, conduit runs across the deck, cyan perimeter lamps."""
    def build():
        octa(4.4, 0.16, 0, 0, 0, P["dark"])
        octa(4.1, 0.14, 0, 0, 0.16, P["hull"])
        for k in range(8):                                                    # capacitor banks round the tube
            a = k * math.pi / 4 + math.pi / 8
            B(0.9, 0.55, 0.7, math.cos(a) * 1.9, math.sin(a) * 1.9, 0.3, P["trim"], rot=a, bevel=0.04)
            for j in range(3):
                cyl(0.1, 0.12, math.cos(a) * 1.9 + math.cos(a + 1.57) * (j - 1) * 0.25, math.sin(a) * 1.9 + math.sin(a + 1.57) * (j - 1) * 0.25,
                    1.0, P["steel"], verts=10)
        cyl(1.05, 0.5, 0, 0, 0.3, P["trim"], verts=48)
        cyl(0.8, 2.8, 0, 0, 0.8, P["hull"], verts=48)
        for z in (1.2, 1.8, 2.4, 3.0, 3.45):
            tor(0.86, 0.08, 0, 0, z, P["trim"])
        tor(0.82, 0.05, 0, 0, 3.62, P["glass"])
        cyl(0.62, 0.05, 0, 0, 3.58, P["dark"], verts=48)
        # The gantry: a ribbed tower north-west, a swing arm to the tube's top.
        B(0.8, 0.8, 4.2, -2.8, 2.8, 0.3, P["hull"], bevel=0.05)
        for z in (1.0, 1.8, 2.6, 3.4): B(0.84, 0.84, 0.08, -2.8, 2.8, z, P["trim"], bevel=0.01)
        for d in (-0.25, 0.0, 0.25):                                           # ribs up its faces, a ladder
            B(0.06, 0.86, 3.9, -2.8 + d, 2.8, 0.4, P["trim"], bevel=0.005); B(0.86, 0.06, 3.9, -2.8, 2.8 + d, 0.4, P["trim"], bevel=0.005)
        for k in range(14): rod((-2.35, 2.62, 0.5 + k * 0.27), (-2.35, 2.98, 0.5 + k * 0.27), 0.012, P["steel"])
        cyl(0.08, 0.1, -2.8, 2.8, 4.5, P["light"], verts=12)
        B(2.2, 0.25, 0.2, -1.7, 1.7, 3.6, P["trim"], rot=-math.pi / 4, bevel=0.02)
        for x, y in ((2.9, 2.9), (3.1, 1.6)):                                  # tanks north-east
            sph(0.62, x, y, 0.95, P["trim"]); cyl(0.25, 0.35, x, y, 0.3, P["dark"], verts=16)
        pipe([(2.9, 2.9, 0.4), (1.4, 1.4, 0.4), (0.9, 0.9, 0.5)], 0.08, P["steel"], P["dark"])
        for k in range(12):
            a = k * 2 * math.pi / 12
            cyl(0.08, 0.12, math.cos(a) * 3.9, math.sin(a) * 3.9, 0.3, P["light"], verts=10)
        for k in range(4): B(1.6, 0.18, 0.06, 0, -2.6 - k * 0.32, 0.3, P["accent"] if k % 2 == 0 else P["dark"], bevel=0.0)
    return _still(build)


def launchpad_kh_b():
    """A sealed silo cap: a round raised rim, a segmented dome shut over the launch well, three service towers round it
    joined by a ring walkway, cyan lights in the dome's seams."""
    def build():
        octa(4.4, 0.16, 0, 0, 0, P["dark"])
        cyl(3.2, 0.6, 0, 0, 0.16, P["hull"], verts=64)
        tor(3.2, 0.12, 0, 0, 0.76, P["trim"])
        bpy.ops.mesh.primitive_uv_sphere_add(radius=2.5, location=(0, 0, 0.76), segments=48, ring_count=24)
        o = bpy.context.object; o.scale = (1, 1, 0.45); o.data.materials.append(P["trim"])
        for k in range(8):
            a = k * math.pi / 4
            rod((0, 0, 1.9), (math.cos(a) * 2.5, math.sin(a) * 2.5, 0.8), 0.03, P["glass"])
        for k in range(3):
            a = k * 2 * math.pi / 3 + 0.5
            x, y = math.cos(a) * 3.6, math.sin(a) * 3.6
            B(0.7, 0.7, 2.6, x, y, 0.16, P["hull"], rot=a, bevel=0.04); cyl(0.07, 0.1, x, y, 2.76, P["light"], verts=12)
        tor(3.6, 0.06, 0, 0, 1.9, P["steel"])
    return _still(build)


def launchpad_gs_a():
    """A scrap launch rail: a scorched slab, a girder ramp raked up to the north from a sled on rails, its launch end on
    an A-frame; a gantry crane of welded girders over the sled, salvaged tanks and drums, a blast shield of plate."""
    import random as _r
    rr = _r.Random(31)
    def build():
        B(8.2, 8.2, 0.12, 0, 0, 0, P["dark"], bevel=0.05)
        cyl(1.6, 0.02, 0, 0, 0.12, P["rubber"], verts=40)                      # the scorch
        for sx in (-1, 1):                                                    # the rails, raked up north
            o = B(0.12, 6.0, 0.14, sx * 0.45, 0.2, 0.9, P["trim"], bevel=0.01); o.rotation_euler.x = math.radians(22)
        for k in range(8):
            y = -2.3 + k * 0.7; z = 0.2 + (y + 2.7) * math.tan(math.radians(22))
            o = B(1.2, 0.1, 0.08, 0, y, z - 0.08, P["hull"], bevel=0.005); o.rotation_euler.x = math.radians(22)
            if k % 2 == 0:
                for sx in (-1, 1): rod((sx * 0.5, y, 0.12), (sx * 0.5, y, z - 0.05), 0.05, P["steel"])
        B(1.0, 1.4, 0.4, 0, -2.4, 0.2, P["accent"], bevel=0.03)                 # the sled, a cradle on it
        for sx in (-1, 1):                                                    # a gantry crane over it
            rod((sx * 1.6, -3.2, 0.12), (sx * 1.6, -3.2, 3.0), 0.08, P["trim"]); rod((sx * 1.6, -1.4, 0.12), (sx * 1.6, -1.4, 3.0), 0.08, P["trim"])
            rod((sx * 1.6, -3.2, 3.0), (sx * 1.6, -1.4, 3.0), 0.07, P["hull"])
        rod((-1.6, -2.3, 3.0), (1.6, -2.3, 3.0), 0.09, P["hull"])
        for k in range(3):
            x, y = 2.6 + (k % 2) * 0.4, 1.5 + k * 1.0
            lie(0.4, 1.4, x, y, 0.55, P["hull"] if k % 2 else P["trim"], "y", 20)
        for k in range(9): cyl(0.18, 0.45, -2.8 + (k % 3) * 0.4, 2.0 + (k // 3) * 0.4, 0.12, P["accent"] if k % 2 else P["steel"], verts=14)
        for k in range(5):
            o = B(0.8, 0.06, 1.2, -3.2 + k * 0.82, -3.6, 0.12, P["trim"] if k % 2 else P["hull"], bevel=0.005)
            o.rotation_euler = (math.radians(rr.uniform(-8, 8)), 0, math.radians(rr.uniform(-6, 6)))
    return _still(build)


def launchpad_gs_b():
    """A hull hatch: a pit lined with welded plate, its lid a ship's hull section on a hinge, propped; a lattice derrick
    over it, a winch house, fuel tanks on cradles, cable runs, an amber beacon on the derrick."""
    def build():
        B(8.2, 8.2, 0.12, 0, 0, 0, P["dark"], bevel=0.05)
        cyl(2.3, 0.4, 0, 0, 0.12, P["trim"], verts=40); cyl(2.0, 0.42, 0, 0, 0.12, P["rubber"], verts=40)
        tor(2.15, 0.06, 0, 0, 0.53, P["hazard"])                                # the well's hazard ring
        cyl(3.0, 0.015, 0, 0, 0.12, P["rubber"], verts=48)                      # scorched round it
        o = B(4.2, 2.2, 0.18, 0, 1.6, 1.2, P["hull"], bevel=0.08); o.rotation_euler.x = math.radians(-55)
        rod((-1.2, 0.8, 0.5), (-1.2, 1.7, 2.4), 0.06, P["steel"]); rod((1.2, 0.8, 0.5), (1.2, 1.7, 2.4), 0.06, P["steel"])
        legs = [(-2.0, -2.0), (2.0, -2.0), (2.0, 2.0), (-2.0, 2.0)]
        for x, y in legs: rod((x * 1.3, y * 1.3, 0.12), (x * 0.25, y * 0.25, 5.0), 0.07, P["trim"])
        for z in (1.2, 2.4, 3.6):
            k = 1 - (z - 0.12) / 4.88 * 0.81
            for i in range(4):
                a, b2 = legs[i], legs[(i + 1) % 4]
                rod((a[0] * 1.3 * k, a[1] * 1.3 * k, z), (b2[0] * 1.3 * k, b2[1] * 1.3 * k, z), 0.035, P["steel"])
        sph(0.09, 0, 0, 5.05, P["light"])
        B(1.2, 1.0, 0.9, 3.0, -2.8, 0.12, P["hull"], bevel=0.03); lie(0.3, 0.8, 3.0, -2.0, 0.6, P["dark"], "x", 18)
        for k in range(2): lie(0.45, 1.8, -3.0, -1.0 + k * 1.1, 0.6, P["accent"] if k else P["trim"], "y", 20)
    return _still(build)


# The finals: the chosen concept (kh-a for KH's depot and launchpad; gs-a for Grubstake's depot, gs-b its launchpad) and
# the machinery that makes it read made beside vanilla's dense cargo pad and silo (the clay concepts read sparse there):
# pumps, motors, cabinets, gauges, pipe and cable runs, props, then small parts scattered over its large faces.
def kit(x, y, z, rot, kind, k=1.0):
    """A machine cluster at (x, y, z) facing rot: 'pump' a motor on a pump body and its pipe stub, 'cab' a cabinet with
    its screen, gauge and conduit, 'manifold' a pipe manifold with valves, 'tank' a small upright tank on legs."""
    c, sn = math.cos(rot), math.sin(rot)
    def at(dx, dy): return x + dx * c - dy * sn, y + dx * sn + dy * c
    if kind == "pump":
        B(0.4 * k, 0.3 * k, 0.22 * k, x, y, z, P["trim"], rot=rot, bevel=0.02)
        mx, my = at(0.05, 0)
        motor(mx, my, z + 0.34 * k, 0.1 * k, 0.32 * k, P["hull"], P["steel"], axis="x" if abs(c) > abs(sn) else "y")
        px, py = at(-0.25 * k, 0.1 * k)
        pipe([(px, py, z + 0.1), (px, py, z + 0.4 * k), at(-0.25 * k, 0.4 * k) + (z + 0.45 * k,)], 0.035 * k, P["steel"], P["dark"])
    elif kind == "cab":
        B(0.5 * k, 0.28 * k, 0.55 * k, x, y, z, P["hull"], rot=rot, bevel=0.02)
        gx, gy = at(0, -0.15 * k)
        B(0.3 * k, 0.02, 0.18 * k, gx, gy, z + 0.3 * k, P["glass"], rot=rot, bevel=0.0)
        gauge(*at(0.18 * k, -0.15 * k), z + 0.15 * k, P["dark"], P["trim"])
        rod((x, y, z + 0.55 * k), (x, y, z + 0.75 * k), 0.02, P["rubber"])
    elif kind == "manifold":
        ax, ay = at(-0.35 * k, 0); bx, by = at(0.35 * k, 0)
        pipe([(ax, ay, z + 0.15), (bx, by, z + 0.15)], 0.05 * k, P["steel"], P["dark"])
        for d in (-0.2, 0.0, 0.2):
            vx, vy = at(d * k, 0)
            rod((vx, vy, z + 0.15), (vx, vy, z + 0.35 * k), 0.025 * k, P["steel"])
            cyl(0.05 * k, 0.02, vx, vy, z + 0.35 * k, P["accent"], verts=10)
    elif kind == "tank":
        cyl(0.2 * k, 0.5 * k, x, y, z + 0.12 * k, P["trim"], verts=18); sph(0.2 * k, x, y, z + 0.62 * k, P["trim"])
        for a in (0.5, 2.6, 4.7):
            rod((x + math.cos(a) * 0.18 * k, y + math.sin(a) * 0.18 * k, z), (x + math.cos(a) * 0.15 * k, y + math.sin(a) * 0.15 * k, z + 0.2 * k), 0.015, P["dark"])


def crates(x, y, z, n, rng, mats, k=1.0):
    """A stack of crates at (x, y, z): n of them, two courses, turned a little."""
    for i in range(n):
        cx, cy = x + (i % 2) * 0.32 * k + rng.uniform(-0.03, 0.03), y + ((i // 2) % 2) * 0.32 * k
        cz = z + (i // 4) * 0.28 * k
        B(0.3 * k, 0.3 * k, 0.27 * k, cx, cy, cz, rng.choice(mats), rot=rng.uniform(-0.25, 0.25), bevel=0.012)


def drums(x, y, z, n, rng, mats, k=1.0):
    for i in range(n):
        a = i * 2.4
        cx, cy = x + math.cos(a) * 0.18 * k * (i > 0), y + math.sin(a) * 0.18 * k * (i > 0)
        cyl(0.11 * k, 0.32 * k, cx, cy, z, rng.choice(mats), verts=14); tor(0.11 * k, 0.008, cx, cy, z + 0.22 * k, P["dark"])


def railing(pts, z, m, post=0.5):
    """A pipe railing along points at height z above each point's base: a top rail, a mid rail, posts."""
    for (x0, y0, b0), (x1, y1, b1) in zip(pts, pts[1:]):
        rod((x0, y0, b0 + z), (x1, y1, b1 + z), 0.015, m); rod((x0, y0, b0 + z * 0.5), (x1, y1, b1 + z * 0.5), 0.01, m)
        L = math.hypot(x1 - x0, y1 - y0); n = max(1, int(L / post))
        for j in range(n + 1):
            u = j / n; rod((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, b0), (x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, b0 + z), 0.012, m)


def cable(p0, p1, sag, m, r=0.012, n=8):
    """A cable hung from p0 to p1, sagging."""
    pts = []
    for j in range(n + 1):
        u = j / n
        pts.append(tuple(p0[q] + (p1[q] - p0[q]) * u for q in range(3)))
        pts[-1] = (pts[-1][0], pts[-1][1], pts[-1][2] - sag * math.sin(u * math.pi))
    for a, b in zip(pts, pts[1:]): rod(a, b, r, m)


def coil(x, y, z, R, m, turns=4):
    for t in range(turns): tor(R - t * 0.02, 0.015, x, y, z + t * 0.025, m)


def arch(p0, p1, h, r, m, flange):
    """A pipe from p0 up, over and down to p1, h above the higher end (vanilla's silo: its hoses loop over its machines)."""
    top = max(p0[2], p1[2]) + h
    pipe([p0, (p0[0], p0[1], top), (p1[0], p1[1], top), p1], r, m, flange)


def perimeter(path, z, rng, k=1.0, step=0.42, faction="kh", closed=True):
    """A wall of machinery along a closed path of (x, y) points, its faces turned inward: blocks of varied height (up
    to about a tile), the kit's clusters between them, a pipe arch every few, a cable bundle along its foot. What made
    vanilla's silo and cargo pad read dense beside ours: machines piled round the whole edge, not spotted on a deck."""
    pts = []
    # (Open where asked: Grubstake's depot's west and north run, closed, crossed its landing circle diagonally.)
    for (x0, y0), (x1, y1) in zip(path, path[1:] + (path[:1] if closed else [])):
        L = math.hypot(x1 - x0, y1 - y0); n = max(1, int(L / (step * k)))
        for j in range(n): pts.append((x0 + (x1 - x0) * j / n, y0 + (y1 - y0) * j / n, math.atan2(y1 - y0, x1 - x0)))
    mats = [P["hull"], P["trim"], P["trim"], P["accent"]] if faction == "gs" else [P["hull"], P["trim"], P["hull"]]
    for i, (x, y, a) in enumerate(pts):
        h = rng.choice((0.3, 0.45, 0.6, 0.8, 1.0)) * k
        kind = i % 5
        if kind in (0, 3):
            B(step * k * 0.95, 0.38 * k, h, x, y, z, rng.choice(mats), rot=a, bevel=0.02)
            if rng.random() < 0.5: B(step * k * 0.5, 0.25 * k, 0.15 * k, x, y, z + h, P["dark"], rot=a, bevel=0.01)
            if rng.random() < 0.4: cyl(0.04 * k, 0.25 * k, x, y, z + h, P["steel"], verts=8)
        elif kind == 1:
            kit(x, y, z, a, rng.choice(("pump", "cab", "tank", "manifold")), 0.9 * k)
        elif kind == 2:
            cyl(0.16 * k, h, x, y, z, rng.choice(mats), verts=16); sph(0.16 * k, x, y, z + h, P["steel"])
        else:
            motor(x, y, z + 0.2 * k, 0.12 * k, step * k * 0.8, rng.choice(mats), P["steel"], axis="x" if abs(math.cos(a)) > 0.7 else "y")
            B(step * k * 0.8, 0.3 * k, 0.1 * k, x, y, z, P["dark"], rot=a, bevel=0.01)
        if i % 4 == 2 and i + 2 < len(pts):
            x2, y2, _ = pts[i + 2]
            arch((x, y, z + 0.5 * k), (x2, y2, z + 0.5 * k), rng.uniform(0.25, 0.6) * k, 0.045 * k,
                 rng.choice((P["steel"], P["accent"], P["trim"])), P["dark"])
    for (x0, y0, _), (x1, y1, _) in zip(pts, pts[1:]):
        rod((x0, y0, z + 0.05), (x1, y1, z + 0.05), 0.03 * k, P["rubber"])


def octagon(r):
    return [(math.cos(math.pi / 8 + j * math.pi / 4) * r, math.sin(math.pi / 8 + j * math.pi / 4) * r) for j in range(8)]


def depot_kh():
    objs, _ = depot_kh_a()
    def more():
        R = 1.62
        for k, (a, kind) in enumerate(((0.4, "pump"), (1.15, "cab"), (2.0, "manifold"), (2.75, "pump"), (3.55, "tank"),
                                       (4.35, "manifold"), (5.6, "pump"))):
            kit(math.cos(a) * R, math.sin(a) * R, 0.3, a + math.pi / 2, kind, 0.85)
        pipe([(1.35, 1.35, 0.35), (1.0, 0.35, 0.35), (0.95, -0.6, 0.35), (0.4, -1.3, 0.35)], 0.04, P["steel"], P["dark"])
        rod((-1.4, 1.2, 0.85), (1.3, 1.35, 1.95), 0.015, P["rubber"])
        cyl(0.05, 0.3, -1.4, 1.2, 0.85, P["steel"], verts=8)                       # a dish on the cabinet's mast
        # (A dish: a shallow steel cone, not a sphere, which read as a white ball; its feed horn on a strut.)
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.3, radius2=0.04, depth=0.1, location=(-1.4, 1.2, 1.25))
        o = bpy.context.object; o.rotation_euler = (math.radians(130), 0, math.radians(-30)); o.data.materials.append(P["steel"])
        rod((-1.4, 1.2, 1.25), (-1.33, 1.05, 1.42), 0.01, P["dark"]); sph(0.03, -1.33, 1.05, 1.42, P["dark"])
        prop("power_box_01_box", "power_box_01", (1.55, -0.9, 0.3), 270, 0.35)
        prop("exterior_aircon_unit", "exterior_aircon_unit", (-1.55, -0.4, 0.3), 90, 0.3)
        # (Denser, the coordinator's review of 0.2.318: plainer than vanilla's dense machines beside it.) Equipment
        # modules on the plinth's sides, cable trays and conduits round the ring, vents, a cargo cart and crates.
        import random as _r
        rr = _r.Random(45)
        for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
            x, y = math.cos(a) * 1.82, math.sin(a) * 1.82
            B(0.7, 0.28, 0.42, x, y, 0.0, P["trim"], rot=a + math.pi / 2, bevel=0.02)
            for j in range(3):
                ox, oy = math.cos(a + math.pi / 2) * (j - 1) * 0.22, math.sin(a + math.pi / 2) * (j - 1) * 0.22
                B(0.14, 0.04, 0.1, x + ox + math.cos(a) * 0.15, y + oy + math.sin(a) * 0.15, 0.28, P["dark"], rot=a + math.pi / 2, bevel=0.0)
        for k in range(24):                                                   # a cable tray round the ring
            a = k * 2 * math.pi / 24
            B(0.2, 0.08, 0.04, math.cos(a) * 1.18, math.sin(a) * 1.18, 0.3, P["dark"], rot=a + math.pi / 2, bevel=0.0)
        for a in (0.8, 2.4, 3.9, 5.5):
            pipe([(math.cos(a) * 1.25, math.sin(a) * 1.25, 0.33), (math.cos(a) * 1.55, math.sin(a) * 1.55, 0.33),
                  (math.cos(a) * 1.55, math.sin(a) * 1.55, 0.05)], 0.03, P["steel"], P["dark"])
        B(0.45, 0.3, 0.16, -0.9, -1.1, 0.3, P["trim"], rot=0.3, bevel=0.02)       # a cargo cart, crates on it
        crates(-1.0, -1.2, 0.46, 3, rr, [P["hull"], P["trim"]], 0.6)
        for x in (-0.5, 0.0, 0.5): B(0.18, 0.12, 0.08, x, -1.55, 0.3, P["dark"], bevel=0.005)   # vents
        cable((-1.4, 1.2, 0.9), (-1.82, 0.0, 0.42), 0.15, P["rubber"])
        # (A wall of machines round the deck's edge, its south side open for the ramp: beside vanilla's cargo pad,
        # spotted machines on a wide deck still read plain.)
        perimeter([(1.55, -1.3), (1.62, 0.6), (1.1, 1.55), (-1.1, 1.55), (-1.62, 0.6), (-1.55, -1.3)], 0.3, rr, 0.62)
    objs += group(more)
    objs += scatter(objs, {P["hull"], P["trim"]}, P["dark"], P["steel"], 41, density=14.0)
    return objs, lambda f, n: None


def depot_gs():
    objs, _ = depot_gs_a()
    def more():
        kit(1.3, -0.9, 0.34, 0.0, "pump", 0.9); kit(0.5, -1.55, 0.34, 0.0, "manifold", 0.9)
        kit(1.45, 0.4, 0.34, math.pi / 2, "cab", 0.85); kit(-0.2, 1.3, 0.34, 0.0, "tank", 0.9)
        prop("old_military_compressor", "old_military_compressor", (0.7, 0.75, 0.34), 30, 0.32)
        prop("small_lpg_tank", "small_lpg_tank", (-0.5, -1.5, 0.34), 90, 0.3)
        prop("security_light", "security_light", (1.7, -1.7, 2.0), 225, 0.4)
        rod((1.3, -0.9, 0.6), (0.1, 1.6, 2.3), 0.012, P["rubber"])
        import random as _r
        rr = _r.Random(23)
        for k in range(14):                                                   # scrap on the deck's edge
            B(rr.uniform(0.06, 0.18), rr.uniform(0.06, 0.18), rr.uniform(0.03, 0.08), rr.uniform(-1.7, 1.7),
              rr.choice((-1.75, 1.75)), 0.34, rr.choice((P["steel"], P["dark"], P["accent"], P["trim"])), rot=rr.uniform(0, 3), bevel=0.005)
        # (Denser, the coordinator's review of 0.2.318: "an empty deck".) The landing circle kept clear for the pods;
        # round it pallets of sacks and crates, coiled cable and hose, a fuel stand and its hose, a toolbox and a
        # workbench, a plank walkway in along the south, a pipe railing on the east and north edges, cables from the
        # hoist and the floodlight, oil stains, pipes run down the stilts.
        Z = 0.34
        for (x, y) in ((1.35, 1.35), (-1.35, 1.4)):                             # pallets of sacks
            B(0.55, 0.45, 0.05, x, y, Z, P["trim"], bevel=0.005)
            for j in range(5): sph(0.12, x - 0.15 + (j % 3) * 0.15, y - 0.08 + (j // 3) * 0.16, Z + 0.12, P["cloth"])
        crates(1.2, -1.45, Z, 5, rr, [P["hull"], P["trim"], P["accent"]], 0.85)
        crates(-0.5, 1.45, Z, 3, rr, [P["hull"], P["trim"]], 0.75)
        drums(1.45, 0.95, Z, 3, rr, [P["accent"], P["steel"], P["hull"]], 0.9)
        coil(-1.45, 0.55, Z, 0.17, P["rubber"]); coil(0.55, 1.5, Z, 0.13, P["steel"], 3)
        B(0.22, 0.18, 0.55, 1.6, 0.0, Z, P["accent"], bevel=0.015)               # a fuel stand, its hose
        gauge(1.6, -0.1, Z + 0.4, P["dark"], P["trim"])
        cable((1.55, 0.0, Z + 0.45), (1.1, 0.4, Z + 0.02), 0.05, P["rubber"], 0.018, 6)
        B(0.5, 0.25, 0.28, -1.5, -0.35, Z, P["trim"], bevel=0.01)               # a workbench, a vice, a toolbox
        B(0.12, 0.08, 0.08, -1.62, -0.35, Z + 0.28, P["steel"], bevel=0.005); B(0.18, 0.1, 0.08, -1.4, -0.32, Z + 0.28, P["accent"], bevel=0.005)
        for j in range(6):                                                    # planks in along the south
            o = B(0.16, 0.6, 0.03, -0.45 + j * 0.17, -2.05, 0.02 + j * 0.0, P["hull"] if j % 2 else P["trim"], rot=rr.uniform(-0.05, 0.05), bevel=0.003)
        railing([(1.85, -1.8, Z), (1.85, 1.85, Z), (-1.85, 1.85, Z)], 0.32, P["steel"], 0.6)
        cable((1.7, -1.7, 1.95), (1.85, 1.0, Z + 0.32), 0.2, P["rubber"])
        cable((0.9, 1.6, 2.3), (1.85, 1.85, Z + 0.32), 0.1, P["rubber"])
        for (x, y, r) in ((0.6, -0.8, 0.22), (-0.7, 0.5, 0.16), (0.2, 0.3, 0.12)):  # oil stains on the deck
            cyl(r, 0.004, x, y, Z + 0.06, P["dark"], verts=16)
        for x in (-1.3, 1.3):
            pipe([(x + 0.12, -1.3, Z), (x + 0.12, -1.3, 0.05)], 0.025, P["steel"], P["dark"])
        # A wall of salvaged machinery and junk along its west and north edges (under the hoist), the circle clear.
        perimeter([(-1.62, -1.55), (-1.62, 1.62), (1.0, 1.62)], Z, rr, 0.6, faction="gs", closed=False)
    objs += group(more)
    objs += scatter(objs, {P["hull"], P["trim"]}, P["dark"], P["steel"], 42, density=12.0)
    return objs, lambda f, n: None


def launchpad_kh():
    objs, _ = launchpad_kh_a()
    def more():
        for k in range(8):
            a = k * math.pi / 4
            kit(math.cos(a) * 3.2, math.sin(a) * 3.2, 0.3, a + math.pi / 2, ("pump", "cab", "manifold", "tank")[k % 4], 1.2)
        for k in range(8):                                                    # conduits from the banks to the tube
            a = k * math.pi / 4 + math.pi / 8
            rod((math.cos(a) * 1.45, math.sin(a) * 1.45, 0.75), (math.cos(a) * 0.95, math.sin(a) * 0.95, 1.1), 0.05, P["rubber"])
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            pipe([(math.cos(a) * 3.7, math.sin(a) * 3.7, 0.32), (math.cos(a) * 2.5, math.sin(a) * 2.5, 0.32)], 0.07, P["steel"], P["dark"])
        prop("exterior_aircon_unit", "exterior_aircon_unit", (3.0, -2.6, 0.3), 0, 0.6)
        prop("power_box_01_box", "power_box_01", (-3.2, -2.4, 0.3), 90, 0.6)
        prop("utility_box_02", "utility_box_02", (-2.0, -3.4, 0.3), 0, 0.6)
        # (Denser, the coordinator's review of 0.2.318.) Grating and cable trays radial between the banks, a coolant
        # loop round the tube's foot, pipe racks on the deck's edges, a maintenance cart, valve stations, vents.
        import random as _r
        rr = _r.Random(47)
        for k in range(8):
            a = k * math.pi / 4
            for j in range(5):
                r = 1.25 + j * 0.42
                B(0.32, 0.12, 0.03, math.cos(a) * r, math.sin(a) * r, 0.3, P["dark"], rot=a, bevel=0.0)
        tor(1.2, 0.06, 0, 0, 0.45, P["steel"]); tor(1.3, 0.04, 0, 0, 0.38, P["accent"])
        for k in range(8):
            a = k * math.pi / 4 + math.pi / 8
            r = 3.85
            pipe([(math.cos(a - 0.3) * r, math.sin(a - 0.3) * r, 0.36), (math.cos(a + 0.3) * r, math.sin(a + 0.3) * r, 0.36)], 0.06, P["steel"], P["dark"])
            pipe([(math.cos(a - 0.3) * (r - 0.15), math.sin(a - 0.3) * (r - 0.15), 0.5), (math.cos(a + 0.3) * (r - 0.15), math.sin(a + 0.3) * (r - 0.15), 0.5)], 0.04, P["trim"], P["dark"])
        for (x, y) in ((2.2, -2.9), (-3.3, 0.6), (0.9, 3.4)):
            kit(x, y, 0.3, rr.uniform(0, 6), "manifold", 1.1); kit(x + 0.5, y + 0.3, 0.3, rr.uniform(0, 6), "cab", 0.9)
        B(0.8, 0.5, 0.3, 1.6, -3.4, 0.3, P["trim"], rot=0.2, bevel=0.03)
        crates(1.4, -3.5, 0.6, 3, rr, [P["hull"], P["trim"]], 0.8)
        for k in range(10):
            a = k * 2 * math.pi / 10 + 0.2
            B(0.25, 0.18, 0.1, math.cos(a) * 2.75, math.sin(a) * 2.75, 0.3, P["dark"], rot=a, bevel=0.005)
        # A wall of machines round the octagon's edge (the silo's: machines piled round its whole rim).
        perimeter(octagon(4.0), 0.3, rr, 1.15)
    objs += group(more)
    objs += scatter(objs, {P["hull"], P["trim"]}, P["dark"], P["steel"], 43, density=11.0)
    return objs, lambda f, n: None


def launchpad_gs():
    objs, _ = launchpad_gs_b()
    def more():
        import random as _r
        rr = _r.Random(33)
        for k in range(10):                                                   # welded plates round the pit's rim
            a = k * 2 * math.pi / 10 + rr.uniform(0, 0.2)
            o = B(1.2, 0.5, 0.06, math.cos(a) * 2.6, math.sin(a) * 2.6, 0.12, P["trim"] if k % 2 else P["hull"], rot=a + math.pi / 2, bevel=0.01)
        kit(3.2, 1.2, 0.12, 0.0, "pump", 1.2); kit(3.4, 2.8, 0.12, 0.0, "tank", 1.3); kit(-3.4, 2.8, 0.12, 0.0, "cab", 1.2)
        kit(0.0, -3.5, 0.12, 0.0, "manifold", 1.4); kit(-1.6, -3.4, 0.12, 0.0, "pump", 1.1)
        gear(3.0, -1.7, 0.9, 0.35, P["steel"], teeth=16, axis="x")
        prop("old_military_compressor", "old_military_compressor", (1.8, -3.2, 0.12), 0, 0.6)
        prop("propane_tank", "propane_tank", (-3.4, 1.6, 0.12), 90, 0.5)
        prop("small_lpg_tank", "small_lpg_tank", (3.4, 0.2, 0.12), 0, 0.5)
        for k in range(3): rod((0.0, 0.0, 5.0), (2.9, -2.1 - k * 0.15, 0.9), 0.012, P["steel"])
        for k in range(4):                                                    # tyre stacks, a scrap heap
            for z in range(3): tor(0.3, 0.11, -3.5 + k * 0.8, -3.6, 0.2 + z * 0.2, P["rubber"])
        for k in range(18):
            B(rr.uniform(0.15, 0.45), rr.uniform(0.15, 0.45), rr.uniform(0.05, 0.2), rr.uniform(2.2, 3.8), rr.uniform(-3.8, -2.6),
              0.12 + rr.uniform(0, 0.25), rr.choice((P["steel"], P["dark"], P["accent"], P["trim"], P["hull"])), rot=rr.uniform(0, 3), bevel=0.01)
        cyl(0.12, 1.4, -3.6, -1.0, 0.12, P["steel"], verts=10); sph(0.12, -3.6, -1.0, 1.6, P["light"])
        # (Denser, the coordinator's review of 0.2.318.) A fuel line from the tanks round the pit to its rim, cables
        # from the winch and the beacon pole, crate stacks, drum groups, sandbags at the pit's south, a generator, a
        # workbench, planks and pallets, pipe railing round the pit's open side.
        Z = 0.12
        pipe([(-3.0, -0.4, 0.5), (-2.6, -0.4, 0.3), (-2.4, -1.6, 0.3), (-1.4, -2.3, 0.3), (0.0, -2.4, 0.45)], 0.07, P["steel"], P["dark"])
        pipe([(3.2, 1.2, 0.4), (2.6, 1.0, 0.3), (2.5, -0.5, 0.3), (2.2, -1.2, 0.45)], 0.06, P["accent"], P["dark"])
        cable((3.0, -2.0, 0.9), (1.2, -1.6, 0.55), 0.15, P["rubber"]); cable((-3.6, -1.0, 1.5), (-2.3, 0.0, 0.55), 0.3, P["rubber"])
        crates(-3.6, 3.2, Z, 6, rr, [P["hull"], P["trim"], P["accent"]], 1.1)
        crates(2.0, 3.4, Z, 4, rr, [P["hull"], P["trim"]], 1.0)
        drums(0.6, 3.5, Z, 4, rr, [P["accent"], P["steel"], P["hull"]], 1.1); drums(-1.2, 3.4, Z, 3, rr, [P["accent"], P["hull"]], 1.1)
        for j in range(9):                                                    # sandbags at the pit's south
            a = math.pi * 1.25 + j * 0.13
            for zz in (0, 1):
                o = B(0.34, 0.2, 0.12, math.cos(a) * 2.55, math.sin(a) * 2.55, 0.52 + zz * 0.12, P["cloth"], rot=a + math.pi / 2 + zz * 0.2, bevel=0.04)
        B(0.7, 0.5, 0.45, -3.4, -2.4, Z, P["accent"], bevel=0.02); motor(-3.4, -2.4, Z + 0.6, 0.12, 0.45, P["trim"], P["steel"], "x")
        B(0.9, 0.4, 0.4, 3.5, -0.9, Z, P["trim"], bevel=0.01); B(0.2, 0.1, 0.1, 3.4, -0.9, Z + 0.4, P["steel"], bevel=0.005)
        for j in range(7):
            B(0.2, 1.0, 0.04, -1.0 + j * 0.22, -3.7, Z, P["hull"] if j % 2 else P["trim"], rot=rr.uniform(-0.06, 0.06), bevel=0.003)
        rail = [(math.cos(a) * 2.45, math.sin(a) * 2.45, 0.52) for a in [math.radians(d) for d in range(-30, 200, 23)]]
        railing(rail, 0.3, P["steel"], 0.5)
        for (x, y, r) in ((1.0, -0.6, 0.5), (-0.9, 0.8, 0.4), (2.9, 2.2, 0.35)):
            cyl(r, 0.004, x, y, Z + 0.01, P["dark"], verts=20)
        # A wall of salvaged machines and junk round the slab's edge.
        perimeter([(-3.85, -3.85), (3.85, -3.85), (3.85, 3.85), (-3.85, 3.85)], Z, rr, 1.15, faction="gs")
    objs += group(more)
    objs += scatter(objs, {P["hull"], P["trim"]}, P["dark"], P["steel"], 44, density=11.0)
    return objs, lambda f, n: None


# --- Turrets: a base (once) and a head in 64 directions, north at the first, clockwise (a rotated sprite's), the same
# head for every state (it does not rise out of the ground). Each builder returns (base, head, its pivot).
def turret_base_kh():
    """Kessler-Hayashi's turret ring: a hexagonal armoured plinth, its plates bolted, a cyan lamp each side, a cable
    into it."""
    octa(0.95, 0.12, 0, 0, 0, P["dark"])
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.85, depth=0.34, location=(0, 0, 0.29))
    bpy.context.object.data.materials.append(P["hull"])
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.88, depth=0.05, location=(0, 0, 0.47))
    bpy.context.object.data.materials.append(P["trim"])
    # (Its deck dark plate: the worn paint's top read pale, a grey hexagon under the head.)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.8, depth=0.03, location=(0, 0, 0.5))
    bpy.context.object.data.materials.append(P["dark"])
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        B(0.32, 0.04, 0.2, math.cos(a) * 0.74, math.sin(a) * 0.74, 0.18, P["trim"], rot=a + math.pi / 2, bevel=0.01)
    for sx in (-1, 1):
        B(0.08, 0.04, 0.06, sx * 0.45, -0.73, 0.34, P["light"], bevel=0.0)
    B(0.12, 0.06, 0.06, 0, -0.75, 0.3, P["accent"], bevel=0.0)
    cyl(0.5, 0.06, 0, 0, 0.5, P["dark"], verts=32)


def turret_kh_laser():
    """A lens turret: a rounded armoured housing, a long emitter tube finned for cooling, its lens lit at the muzzle, a
    sensor block on its side."""
    def base(): turret_base_kh()
    def head():
        cyl(0.42, 0.14, 0, 0, 0.56, P["trim"], verts=32)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.42, location=(0, -0.05, 0.82), segments=32, ring_count=16)
        o = bpy.context.object; o.scale = (1.0, 1.15, 0.62); o.data.materials.append(P["hull"])
        lie(0.09, 0.75, 0, 0.62, 0.86, P["steel"], "y", 16)
        for k in range(5):
            lie(0.13, 0.03, 0, 0.36 + k * 0.08, 0.86, P["dark"], "y", 16)
        lie(0.1, 0.06, 0, 1.0, 0.86, P["trim"], "y", 16)
        lie(0.075, 0.03, 0, 1.04, 0.86, P["light"], "y", 16)
        B(0.16, 0.24, 0.16, 0.36, 0.0, 0.8, P["dark"], bevel=0.01)
        B(0.04, 0.03, 0.04, 0.44, 0.13, 0.88, P["light"], bevel=0.0)
        B(0.5, 0.04, 0.04, 0, -0.5, 0.95, P["accent"], bevel=0.0)
    b = group(base); h = group(head)
    return b, h


def turret_kh_gun():
    """An autocannon turret: a squared armoured head, twin barrels with muzzle brakes, an ammunition drum on its flank,
    its feed chute, a sight on top."""
    def base(): turret_base_kh()
    def head():
        cyl(0.42, 0.14, 0, 0, 0.56, P["trim"], verts=32)
        B(0.62, 0.7, 0.32, 0, -0.05, 0.68, P["hull"], bevel=0.05)
        B(0.5, 0.25, 0.12, 0, 0.18, 1.0, P["hull"], bevel=0.03)
        for sx in (-1, 1):
            lie(0.05, 0.75, sx * 0.13, 0.65, 0.84, P["steel"], "y", 12)
            lie(0.075, 0.12, sx * 0.13, 1.0, 0.84, P["dark"], "y", 12)
            lie(0.07, 0.12, sx * 0.13, 0.3, 0.84, P["dark"], "y", 12)
        lie(0.18, 0.2, 0.42, -0.1, 0.8, P["trim"], "x", 20)
        tor(0.18, 0.02, 0.48, -0.1, 0.8, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
        rod((0.38, -0.05, 0.92), (0.2, 0.15, 0.92), 0.03, P["dark"])
        B(0.12, 0.2, 0.1, -0.18, 0.0, 1.0, P["dark"], bevel=0.01)
        B(0.04, 0.03, 0.03, -0.18, 0.11, 1.05, P["light"], bevel=0.0)
        B(0.5, 0.04, 0.04, 0, -0.42, 0.95, P["accent"], bevel=0.0)
    b = group(base); h = group(head)
    return b, h


def turret_gs():
    """Grubstake's gun nest: a ring of scrap plate and oil drums on a skid, sandbags; the head a welded box behind a
    patched gun shield, one heavy barrel, its ammo can, an amber lamp."""
    import random as _r
    rr = _r.Random(13)
    def base():
        B(1.75, 1.75, 0.1, 0, 0, 0, P["dark"])
        cyl(0.8, 0.32, 0, 0, 0.1, P["trim"], verts=10)
        for k in range(10):
            a = k * 2 * math.pi / 10 + rr.uniform(-0.1, 0.1)
            o = B(0.48, 0.05, 0.26 + rr.uniform(0, 0.08), math.cos(a) * 0.8, math.sin(a) * 0.8, 0.1,
                  rr.choice((P["hull"], P["trim"], P["accent"])), rot=a + math.pi / 2, bevel=0.005)
            o.rotation_euler.x = rr.uniform(-0.08, 0.08)
        for x, y in ((0.75, -0.7), (-0.78, 0.72)):
            cyl(0.15, 0.4, x, y, 0.1, P["accent"] if x > 0 else P["steel"], verts=16)
            tor(0.15, 0.015, x, y, 0.3, P["dark"])
        for k in range(5):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(-0.6 + k * 0.17, -0.82, 0.16), segments=12, ring_count=8)
            o = bpy.context.object; o.scale = (1.3, 0.8, 0.5); o.data.materials.append(P["hull"])
        cyl(0.48, 0.05, 0, 0, 0.42, P["dark"], verts=24)
    def head():
        cyl(0.36, 0.12, 0, 0, 0.47, P["steel"], verts=20)
        B(0.5, 0.55, 0.34, 0, -0.08, 0.59, P["hull"], bevel=0.01)
        o = B(0.8, 0.06, 0.5, 0, 0.3, 0.55, P["trim"], bevel=0.01); o.rotation_euler.x = math.radians(-12)
        B(0.3, 0.07, 0.2, 0.18, 0.31, 0.75, P["accent"], bevel=0.005)
        lie(0.06, 0.95, 0, 0.75, 0.78, P["steel"], "y", 12)
        lie(0.085, 0.2, 0, 0.45, 0.78, P["dark"], "y", 12)
        lie(0.08, 0.1, 0, 1.2, 0.78, P["dark"], "y", 12)
        B(0.2, 0.16, 0.16, 0.33, -0.15, 0.62, P["accent"], bevel=0.01)
        rod((0.25, -0.1, 0.78), (0.05, 0.25, 0.8), 0.02, P["steel"])
        rod((-0.2, -0.3, 0.93), (-0.2, -0.3, 1.25), 0.015, P["steel"])
        sph(0.045, -0.2, -0.3, 1.27, P["light"])
    b = group(base); h = group(head)
    return b, h


def flamer_kh():
    """A fuel-fed flame turret: a long armoured housing (2x3, facing north), its fuel tank at the back with the two pipe
    inlets, a turret ring at its middle; the head a squat armoured nozzle block, the nozzle and its pilot light."""
    def base():
        B(1.4, 2.35, 0.12, 0, 0, 0, P["dark"])
        B(1.3, 2.2, 0.3, 0, 0, 0.12, P["hull"], bevel=0.05)
        B(1.32, 0.05, 0.05, 0, 0.6, 0.42, P["accent"], bevel=0.0)
        lie(0.3, 1.0, 0, -0.65, 0.62, P["trim"], "x", 24)                         # the fuel tank, across the back
        for x in (-0.35, 0.35):
            tor(0.3, 0.025, x, -0.65, 0.62, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
        for x in (-0.5, 0.5):
            lie(0.1, 0.25, x, -1.05, 0.25, P["steel"], "y", 12)                   # the inlets at the back
            lie(0.13, 0.04, x, -1.17, 0.25, P["dark"], "y", 12)
        pipe([(-0.5, -0.95, 0.3), (-0.5, -0.65, 0.35)], 0.05, P["steel"])
        gauge(0.42, -0.98, 0.55, P["dark"], P["trim"])
        cyl(0.45, 0.08, 0, 0.25, 0.42, P["trim"], verts=32)
        for sx in (-1, 1):
            B(0.08, 0.04, 0.08, sx * 0.55, 1.1, 0.3, P["light"], bevel=0.0)
    def head():
        cyl(0.36, 0.1, 0, 0, 0.5, P["dark"], verts=24)
        B(0.5, 0.55, 0.28, 0, -0.05, 0.6, P["hull"], bevel=0.05)
        lie(0.07, 0.55, 0, 0.5, 0.74, P["steel"], "y", 14)
        lie(0.1, 0.12, 0, 0.78, 0.74, P["dark"], "y", 14)
        lie(0.04, 0.06, 0, 0.86, 0.66, P["glass"], "y", 10)                        # the pilot light, under the muzzle
        rod((0.18, -0.15, 0.75), (0.08, 0.3, 0.78), 0.025, P["rubber"])
        B(0.5, 0.04, 0.04, 0, -0.33, 0.88, P["accent"], bevel=0.0)
    return group(base), group(head)


def flamer_gs():
    """A drum-fed scrap flamer: a welded skid, two oil drums lashed at the back over the inlets, a pressure bottle and its
    hose, a ring; the head a patched box behind a shield, a long nozzle, its igniter lit amber."""
    def base():
        for sx in (-1, 1):
            B(0.2, 2.4, 0.12, sx * 0.6, 0, 0, P["dark"])
        B(1.3, 2.2, 0.08, 0, 0, 0.12, P["trim"])
        for x in (-0.33, 0.33):
            cyl(0.27, 0.75, x, -0.65, 0.2, P["accent"] if x < 0 else P["hull"], verts=20)
            for z in (0.4, 0.75):
                tor(0.27, 0.02, x, -0.65, z, P["dark"])
        rod((-0.6, -0.95, 0.75), (0.6, -0.95, 0.75), 0.015, P["rubber"])
        for x in (-0.5, 0.5):
            lie(0.09, 0.25, x, -1.05, 0.22, P["steel"], "y", 12)
        lie(0.12, 0.55, 0.45, 0.4, 0.35, P["accent"], "y", 16)                      # a pressure bottle
        rod((0.45, 0.1, 0.4), (0.15, 0.1, 0.5), 0.025, P["rubber"])
        cyl(0.4, 0.08, 0, 0.25, 0.2, P["steel"], verts=12)
        for k, (x, y) in enumerate(((-0.45, 0.6), (-0.4, 0.95))):
            B(0.25, 0.2, 0.15, x, y, 0.2, P["trim"] if k else P["accent"], rot=0.3 * k, bevel=0.005)
    def head():
        cyl(0.3, 0.12, 0, 0, 0.28, P["dark"], verts=12)
        B(0.45, 0.5, 0.3, 0, -0.05, 0.4, P["hull"], bevel=0.01)
        o = B(0.6, 0.05, 0.38, 0, 0.25, 0.38, P["trim"], bevel=0.005); o.rotation_euler.x = math.radians(-10)
        # (Its barrel dark, a worn steel ring at the muzzle: bright, it drew the eye off the rest, "I would darken the
        # bright metal of the cannon", the user's rating, 2026-11-10.)
        lie(0.05, 0.85, 0, 0.6, 0.58, P["dark"], "y", 12)
        lie(0.06, 0.06, 0, 0.9, 0.58, P["trim"], "y", 12)
        lie(0.08, 0.1, 0, 1.0, 0.58, P["dark"], "y", 12)
        sph(0.04, 0.0, 1.05, 0.5, P["light"])
        rod((0.15, -0.2, 0.55), (0.05, 0.3, 0.6), 0.025, P["rubber"])
    return group(base), group(head)


# --- Turret concepts (the coordinator's review, 2026-11-10: the first turrets "read as box kit-bash beside vanilla";
# vanilla's have a readable mechanism, a yoke or trunnion holding the weapon, the barrel's mass, a layered base with
# cabling). Clay first, three a turret, shot at the game's zoom beside vanilla: WHAT concept, F its name.
def kh_base_layered():
    """A layered base: an octagonal footplate, four buttress feet, a skirt, a geared turntable ring (vanilla's gun turret
    shows its ring's teeth), cable conduits curving up into the turntable."""
    # (Lower and more open than the first: a heavy plain octagon outweighed the weapon, vanilla's base is a geared ring.)
    octa(0.8, 0.08, 0, 0, 0, P["dark"])
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        o = B(0.22, 0.42, 0.24, math.cos(a) * 0.6, math.sin(a) * 0.6, 0.08, P["hull"], rot=a + math.pi / 2, bevel=0.05)
        cyl(0.04, 0.04, math.cos(a) * 0.72, math.sin(a) * 0.72, 0.32, P["steel"], verts=8)
    cyl(0.5, 0.3, 0, 0, 0.08, P["trim"], verts=32, bevel=0.04)
    cyl(0.66, 0.05, 0, 0, 0.38, P["trim"], verts=40)
    cyl(0.56, 0.1, 0, 0, 0.43, P["dark"], verts=40)
    for k in range(32):
        a = k * 2 * math.pi / 32
        B(0.05, 0.07, 0.08, math.cos(a) * 0.57, math.sin(a) * 0.57, 0.43, P["steel"], rot=a, bevel=0.0)
    for sx in (-1, 1):
        pipe([(sx * 0.8, -0.3, 0.12), (sx * 0.78, -0.3, 0.32), (sx * 0.55, -0.15, 0.42)], 0.04, P["rubber"])
    B(0.3, 0.06, 0.16, 0, -0.66, 0.14, P["accent"], bevel=0.01)
    for sx in (-1, 1):
        B(0.07, 0.04, 0.07, sx * 0.25, -0.69, 0.2, P["light"], bevel=0.0)


def skid_lip(w, d, h):
    """A lit top edge round a skid: a worn steel angle on its rim, catching the sun (the skid reads as a raised object)."""
    for sy in (-1, 1):
        B(w, 0.06, 0.03, 0, sy * (d / 2 - 0.03), h, P["steel"], bevel=0.0)
    for sx in (-1, 1):
        B(0.06, d, 0.03, sx * (w / 2 - 0.03), 0, h, P["steel"], bevel=0.0)


def gs_base_sandbags():
    """Stacked sandbags round a scrap ring: two courses of modelled bags, the top course staggered, an open gap behind,
    an ammo crate and a drum inside."""
    import random as _r
    rr = _r.Random(21)
    # (A skid 0.2 deep, its load lifted onto it after: at 0.06 the plate cast nothing past its edge and showed no side, and
    # the nest read as a decal on the grass, "transparent", the user, 2026-11-11.)
    plate = B(1.7, 1.7, 0.2, 0, 0, 0, P["skid"])
    skid_lip(1.7, 1.7, 0.2)
    before = set(scene.objects)
    cyl(0.46, 0.38, 0, 0, 0.06, P["trim"], verts=10)
    for course, (R, z, n, off) in enumerate(((0.74, 0.06, 13, 0.0), (0.72, 0.19, 12, 0.5), (0.7, 0.32, 12, 0.0))):
        for k in range(n):
            a = (k + off) * 2 * math.pi / n + rr.uniform(-0.04, 0.04)
            if math.sin(a) < -0.85: continue                       # (an opening to the south, behind the gun)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(math.cos(a) * R, math.sin(a) * R, z + 0.07),
                                                 segments=14, ring_count=8)
            o = bpy.context.object; o.scale = (0.2, 0.11, 0.075); o.rotation_euler = (rr.uniform(-0.1, 0.1), 0, a + math.pi / 2)
            o.data.materials.append(P["cloth"])
            # (A tie across each bag's end: a sandbag, not a pebble.)
            tor(0.045, 0.008, math.cos(a) * R + math.cos(a + math.pi / 2) * 0.17, math.sin(a) * R + math.sin(a + math.pi / 2) * 0.17,
                z + 0.07, P["rubber"]).rotation_euler = (math.pi / 2, 0, a + math.pi / 2)
    B(0.3, 0.2, 0.18, 0.35, -0.45, 0.06, P["trim"], rot=0.3, bevel=0.01)
    cyl(0.12, 0.3, -0.42, -0.4, 0.06, P["accent"], verts=14)
    for o in scene.objects:
        if o not in before and o.parent is None: o.location.z += GS_SKID
GS_SKID = 0.14   # (what Grubstake's sandbag nest stands on lifts it, and its gun with it: concept)


def concept(name):
    """(base, head) of a concept; the head's weapon along +y (north), its pivot the origin."""
    if name.startswith("kh-"):
        base = group(kh_base_layered)
    else:
        base = group(gs_base_sandbags)
    def h():
        if name == "kh-laser-yoke":
            # A finned emitter pod held between two cheeks on trunnions, its lens hood at the front, a power pack and
            # heat sinks at the back, cables looping from the cheeks into it.
            cyl(0.4, 0.1, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            for sx in (-1, 1):
                B(0.1, 0.34, 0.62, sx * 0.3, 0, 0.6, P["hull"], bevel=0.04)
                lie(0.08, 0.12, sx * 0.3, 0, 1.08, P["trim"], "x", 16)
            lie(0.2, 0.85, 0, 0.08, 1.08, P["trim"], "y", 8)
            for k in range(4):
                lie(0.225, 0.04, 0, -0.22 + k * 0.12, 1.08, P["dark"], "y", 8)
            bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.2, radius2=0.25, depth=0.22, location=(0, 0.6, 1.08),
                                            rotation=(-math.pi / 2, 0, 0))
            bpy.context.object.data.materials.append(P["dark"])
            lie(0.15, 0.02, 0, 0.7, 1.08, P["glass"], "y", 16)
            B(0.34, 0.28, 0.26, 0, -0.45, 0.97, P["hull"], bevel=0.04)
            for k in range(5):
                B(0.04, 0.24, 0.2, -0.12 + k * 0.06, -0.62, 0.99, P["steel"], bevel=0.0)
            for sx in (-1, 1):
                pipe([(sx * 0.3, -0.15, 0.8), (sx * 0.24, -0.35, 0.85), (sx * 0.12, -0.5, 1.0)], 0.03, P["rubber"])
        elif name == "kh-laser-neck":
            # A tall ribbed neck (vanilla's laser stands its emitter up), a long chamfered emitter housing on a
            # trunnion at its top, twin rails along its sides, a focusing ring and lens at the front, heat-sink fins on
            # its back, a cable coiled down the neck into the base.
            cyl(0.34, 0.1, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.25, radius2=0.13, depth=0.8, location=(0, -0.08, 1.03))
            bpy.context.object.data.materials.append(P["hull"])
            for z in (0.72, 0.92, 1.12, 1.3):
                tor(0.22 - (z - 0.7) * 0.15, 0.025, 0, -0.08, z, P["dark"])
            for sx in (-1, 1):
                B(0.07, 0.22, 0.3, sx * 0.17, -0.05, 1.3, P["hull"], bevel=0.03)
            lie(0.06, 0.42, 0, -0.05, 1.5, P["trim"], "x", 14)
            B(0.3, 1.0, 0.3, 0, 0.12, 1.42, P["trim"], bevel=0.08)
            B(0.32, 0.5, 0.06, 0, 0.0, 1.72, P["hull"], bevel=0.02)
            for sx in (-1, 1):
                lie(0.035, 1.0, sx * 0.17, 0.22, 1.56, P["steel"], "y", 10)
            tor(0.16, 0.045, 0, 0.64, 1.57, P["dark"]).rotation_euler = (math.pi / 2, 0, 0)
            lie(0.12, 0.03, 0, 0.67, 1.57, P["glass"], "y", 16)
            for k in range(5):
                B(0.26, 0.03, 0.12, 0, -0.32 + k * 0.07, 1.75, P["dark"], bevel=0.0)
            for k in range(7):
                tor(0.075, 0.02, 0.3, -0.18, 0.62 + k * 0.09, P["rubber"])
            pipe([(0.3, -0.18, 1.25), (0.22, -0.25, 1.45), (0.1, -0.35, 1.5)], 0.03, P["rubber"])
        elif name == "kh-laser-triple":
            # Three emitter tubes in a triangle, clamped by collars, on a yoke; a power cell behind.
            cyl(0.4, 0.1, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            for sx in (-1, 1):
                B(0.1, 0.3, 0.55, sx * 0.32, 0, 0.6, P["hull"], bevel=0.04)
            for a in (math.pi / 2, math.pi / 2 + 2.1, math.pi / 2 - 2.1):
                lie(0.07, 1.0, math.cos(a) * 0.13, 0.15, 1.05 + math.sin(a) * 0.13, P["steel"], "y", 12)
                lie(0.05, 0.03, math.cos(a) * 0.13, 0.66, 1.05 + math.sin(a) * 0.13, P["glass"], "y", 12)
            for y in (-0.15, 0.25, 0.55):
                lie(0.25, 0.08, 0, y, 1.05, P["trim"], "y", 16)
            B(0.4, 0.3, 0.3, 0, -0.45, 0.92, P["hull"], bevel=0.05)
        elif name == "kh-gun-twin":
            # A mantlet block on trunnions between two tall cheeks, twin long barrels with recoil sleeves and muzzle
            # brakes, an ammunition drum on the right cheek and its belt up into the breech, a sight on top.
            cyl(0.42, 0.12, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            for sx in (-1, 1):
                B(0.1, 0.46, 0.72, sx * 0.34, -0.05, 0.62, P["hull"], bevel=0.05)
                lie(0.09, 0.14, sx * 0.34, 0.0, 1.18, P["trim"], "x", 16)
            B(0.56, 0.46, 0.38, 0, 0.02, 1.0, P["trim"], bevel=0.09)
            for sx in (-1, 1):
                lie(0.075, 0.32, sx * 0.13, 0.4, 1.2, P["dark"], "y", 12)
                lie(0.045, 0.85, sx * 0.13, 0.9, 1.2, P["steel"], "y", 12)
                B(0.12, 0.13, 0.11, sx * 0.13, 1.33, 1.145, P["dark"], bevel=0.02)
            lie(0.24, 0.18, 0.52, -0.1, 0.92, P["trim"], "x", 22)
            tor(0.24, 0.025, 0.62, -0.1, 0.92, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
            for k in range(9):
                t = k / 8
                B(0.1, 0.05, 0.03, 0.52 - t * 0.35, -0.1 + t * 0.15, 1.12 + math.sin(t * math.pi) * 0.14, P["accent"], bevel=0.0)
            B(0.14, 0.22, 0.13, -0.15, -0.05, 1.38, P["dark"], bevel=0.02)
            B(0.05, 0.03, 0.04, -0.15, 0.07, 1.44, P["light"], bevel=0.0)
        elif name == "kh-gun-rotary":
            # A six-barrel rotary cluster on a yoke, front and middle clamps, its motor behind, a big ammo box on the
            # side and its belt curving up into the breech.
            cyl(0.42, 0.1, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            for sx in (-1, 1):
                B(0.1, 0.36, 0.48, sx * 0.3, 0, 0.6, P["hull"], bevel=0.04)
            lie(0.18, 0.4, 0, -0.05, 0.95, P["trim"], "y", 16)
            for k in range(6):
                a = k * math.pi / 3
                lie(0.035, 0.85, math.cos(a) * 0.1, 0.55, 0.95 + math.sin(a) * 0.1, P["steel"], "y", 8)
            for y in (0.45, 0.9):
                lie(0.15, 0.05, 0, y, 0.95, P["dark"], "y", 16)
            lie(0.14, 0.25, 0, -0.38, 0.95, P["dark"], "y", 16)
            B(0.3, 0.4, 0.3, 0.52, -0.1, 0.6, P["trim"], bevel=0.04)
            for k in range(8):
                t = k / 7
                B(0.1, 0.05, 0.03, 0.5 - t * 0.35, -0.05 + t * 0.15, 0.92 + math.sin(t * math.pi) * 0.12, P["accent"], bevel=0.0)
        elif name == "kh-gun-heavy":
            # A low wide armoured housing, one long heavy barrel with its fume extractor and muzzle brake, a cupola.
            cyl(0.48, 0.1, 0, 0, 0.53, P["hull"], verts=24, bevel=0.02)
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.45, depth=0.36, location=(0, -0.05, 0.81), rotation=(0, 0, math.pi / 8))
            o = bpy.context.object; o.scale = (0.9, 1.1, 1); o.data.materials.append(P["trim"])
            lie(0.08, 1.15, 0, 0.85, 0.85, P["steel"], "y", 14)
            lie(0.11, 0.2, 0, 0.75, 0.85, P["dark"], "y", 14)
            B(0.2, 0.18, 0.14, 0, 1.45, 0.78, P["dark"], bevel=0.03)
            cyl(0.14, 0.14, -0.15, -0.15, 0.99, P["hull"], verts=16, bevel=0.03)
        elif name == "gs-pintle":
            # A salvaged heavy machine gun on a tall pintle post: its cradle, the receiver, a perforated barrel jacket
            # and flash hider, an ammo can and its belt, spade grips; a shield of two plates welded at an angle, a
            # slit between them, bolts along their edges. (Its gun at 0.94, on a short thick post: at 1.44 on a thin one, under
            # vanilla's sun its shadow fell 1.6 tiles east, apart from the turret's, and the nest read as a flat decal,
            # "transparent", the user, 2026-11-11; now it falls over the sandbags' own.)
            cyl(0.2, 0.1, 0, 0, 0.44, P["steel"], verts=12)
            cyl(0.13, 0.25, 0, 0, 0.54, P["gunmetal"], verts=12)
            B(0.3, 0.34, 0.1, 0, 0, 0.75, P["dark"], bevel=0.02)
            B(0.22, 0.62, 0.22, 0, -0.02, 0.83, P["gunmetal"], bevel=0.04)
            lie(0.065, 0.85, 0, 0.7, 0.94, P["gunmetal"], "y", 12)
            for k in range(6):
                tor(0.07, 0.016, 0, 0.36 + k * 0.1, 0.94, P["dark"]).rotation_euler = (math.pi / 2, 0, 0)
            lie(0.075, 0.12, 0, 1.15, 0.94, P["dark"], "y", 12)
            B(0.2, 0.26, 0.2, 0.24, -0.08, 0.74, P["accent"], bevel=0.02)
            for k in range(6):
                t = k / 5
                B(0.06, 0.05, 0.025, 0.2 - t * 0.12, -0.05 + t * 0.12, 0.95 + math.sin(t * math.pi) * 0.06, P["steel"], bevel=0.0)
            for sx in (-1, 1):
                rod((sx * 0.08, -0.32, 0.92), (sx * 0.12, -0.5, 0.9), 0.022, P["steel"])
            for sx in (-1, 1):
                o = B(0.46, 0.05, 0.5, sx * 0.24, 0.36, 0.62, P["shield"], bevel=0.01)
                o.rotation_euler = (math.radians(-8), 0, sx * math.radians(18))
                # (Its top edge a welded flat bar in Grubstake's ochre: the one bright line, the plates under it dark.)
                o = B(0.48, 0.07, 0.04, sx * 0.24, 0.39, 1.1, P["hull"], bevel=0.005)
                o.rotation_euler = (math.radians(-8), 0, sx * math.radians(18))
                for k in range(4):
                    cyl(0.02, 0.03, sx * (0.06 + k * 0.12), 0.33, 1.07, P["steel"], verts=6)
        elif name == "gs-twin-seat":
            # Two machine guns side by side on a tractor-seat mount, a bent shield over them, a box of belts.
            cyl(0.32, 0.12, 0, 0, 0.44, P["steel"], verts=12)
            B(0.5, 0.35, 0.12, 0, -0.05, 0.56, P["trim"], bevel=0.02)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(0, -0.3, 0.8), segments=16, ring_count=8)
            o = bpy.context.object; o.scale = (1, 0.8, 0.3); o.data.materials.append(P["dark"])
            rod((0, -0.25, 0.68), (0, -0.3, 0.78), 0.03, P["steel"])
            for sx in (-1, 1):
                B(0.14, 0.4, 0.14, sx * 0.17, 0.12, 0.7, P["hull"], bevel=0.02)
                lie(0.045, 0.6, sx * 0.17, 0.6, 0.78, P["steel"], "y", 10)
            o = B(0.7, 0.04, 0.32, 0, 0.36, 0.62, P["accent"], bevel=0.01); o.rotation_euler.x = math.radians(-15)
            B(0.24, 0.18, 0.16, 0.38, -0.1, 0.56, P["trim"], bevel=0.02)
        elif name == "gs-tripod":
            # A salvaged autocannon on a heavy tripod pintle, a drum magazine on top, a single plate shield, its
            # recoil spring.
            for a in (0.5, 2.6, 4.7):
                rod((0, 0, 0.75), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.44), 0.035, P["steel"])
            cyl(0.07, 0.35, 0, 0, 0.55, P["steel"], verts=12)
            B(0.24, 0.6, 0.22, 0, 0.0, 0.88, P["hull"], bevel=0.03)
            lie(0.07, 0.75, 0, 0.65, 1.0, P["steel"], "y", 12)
            lie(0.09, 0.14, 0, 1.02, 1.0, P["dark"], "y", 12)
            cyl(0.17, 0.08, 0, -0.08, 1.1, P["accent"], verts=20)
            o = B(0.55, 0.04, 0.45, 0, 0.3, 0.75, P["trim"], bevel=0.01); o.rotation_euler.x = math.radians(-10)
    head = group(h)
    if not name.startswith("kh-"):
        for o in head:
            if o.parent is None: o.location.z += GS_SKID
    if name == "kh-gun-twin":
        # (Its mantlet, barrels and drum 0.28 lower, the cheeks sunk into the ring: at 1.2 its barrels' shadow fell apart
        # from the base's, as Grubstake's gun's did, a decal on the grass, 2026-11-11.)
        for o in head:
            if o.parent is None and o.location.z > 0.6: o.location.z -= 0.28
    return base, head


# (The second turrets, from the clay concepts the coordinator's review asked for; the first, turret_kh_laser and the
# rest above, read as box kit-bash.)
def fconcept(name):
    """(base, head) of a flamer concept: the base 2x3 facing north (its inlets south), the head on a pivot at the entity's
    centre, its nozzle north; a pilot light (glass) at the nozzle's tip."""
    kh = name.startswith("kh-")
    def base():
        if kh:
            # An armoured plinth, two banded fuel tanks standing at the back over the inlets, their fuel lines curving
            # up into a raised turret ring, a pump between them, lamps at the front.
            B(1.4, 2.35, 0.1, 0, 0, 0, P["dark"])
            B(1.25, 2.15, 0.22, 0, 0.05, 0.1, P["hull"], bevel=0.06)
            for x in (-0.36, 0.36):
                cyl(0.27, 0.42, x, -0.62, 0.32, P["trim"], verts=24, bevel=0.03)
                for z in (0.42, 0.66):
                    tor(0.27, 0.025, x, -0.62, z, P["dark"])
                bpy.ops.mesh.primitive_uv_sphere_add(radius=0.27, location=(x, -0.62, 0.74), segments=24, ring_count=12)
                o = bpy.context.object; o.scale = (1, 1, 0.45); o.data.materials.append(P["trim"])
                lie(0.09, 0.3, x, -1.07, 0.25, P["steel"], "y", 12)
                pipe([(x, -0.45, 0.75), (x * 0.5, -0.15, 0.7), (x * 0.3, 0.0, 0.8), (x * 0.3, 0.05, 0.85)], 0.04, P["steel"], P["dark"])
            B(0.3, 0.3, 0.3, 0, -0.95, 0.32, P["dark"], bevel=0.03)
            cyl(0.4, 0.2, 0, 0.0, 0.32, P["hull"], verts=32, bevel=0.03)
            # (The neck: the head stands up over the tanks, as vanilla's does; nearer the camera than the head, the
            # tanks hid it, the first clay.)
            # (A short thick neck: at 0.85 its arm's nozzle stood at 2.1 and its shadow fell apart from the plinth's, the
            # flamer a decal on the grass, as Grubstake's were, 2026-11-11.)
            cyl(0.26, 0.35, 0, 0.0, 0.52, P["hull"], verts=16, bevel=0.02)
            tor(0.27, 0.025, 0, 0.0, 0.7, P["dark"])
            cyl(0.32, 0.05, 0, 0.0, 0.87, P["trim"], verts=32)
            for sx in (-1, 1):
                B(0.08, 0.04, 0.08, sx * 0.5, 1.12, 0.22, P["light"], bevel=0.0)
            B(1.27, 0.05, 0.05, 0, 0.75, 0.3, P["accent"], bevel=0.0)
        else:
            # A welded skid, three oil drums lashed upright at the back over the inlets, hoses from them into a ring on
            # a short drum stand, a hand pump, scrap.
            # (Its skid lighter than its shadow, a lit edge: near black, the user saw a shadow over it, 2026-11-11.)
            for sx in (-1, 1):
                B(0.2, 2.4, 0.12, sx * 0.6, 0, 0, P["skid"])
            B(1.3, 2.2, 0.08, 0, 0, 0.12, P["skid"])
            skid_lip(1.3, 2.2, 0.2)
            for k, x in enumerate((-0.42, 0.0, 0.42)):
                cyl(0.19, 0.48, x, -0.7, 0.2, (P["accent"], P["hull"], P["trim"])[k], verts=20, bevel=0.02)
                for z in (0.32, 0.6):
                    tor(0.19, 0.018, x, -0.7, z, P["dark"])
                pipe([(x, -0.6, 0.68), (x * 0.6, -0.3, 0.7), (x * 0.2, -0.06, 0.66), (x * 0.15, -0.06, 0.6)], 0.03, P["rubber"])
            rod((-0.65, -0.92, 0.6), (0.65, -0.92, 0.6), 0.014, P["rubber"])
            for x in (-0.5, 0.5):
                lie(0.09, 0.25, x, -1.05, 0.22, P["steel"], "y", 12)
            cyl(0.3, 0.3, 0, 0.0, 0.2, P["gunmetal"], verts=14)
            # (The boom's ring on the drum stand itself: on a 0.9 pipe mast its boom stood at 2.2, its shadow 2.4 tiles
            # east under vanilla's sun, apart from the skid's, and the flamer read as a flat decal, "transparent", the
            # user, 2026-11-11.)
            cyl(0.26, 0.1, 0, 0.0, 0.5, P["dark"], verts=14)
            B(0.12, 0.12, 0.35, 0.5, 0.5, 0.2, P["steel"], bevel=0.01)
            rod((0.5, 0.5, 0.55), (0.62, 0.62, 0.7), 0.02, P["steel"])
    def head():
        if name == "kh-flame-arm":
            # An articulated arm: a shoulder housing on the ring, the upper arm raised, an elbow, the forearm level with
            # the nozzle and its flared tip, a hose along it, the pilot light lit under the tip.
            B(0.52, 0.52, 0.38, 0, 0.0, 0.6, P["hull"], bevel=0.08)
            lie(0.14, 0.6, 0, 0.08, 0.9, P["trim"], "x", 16)
            o = B(0.24, 0.24, 0.62, 0, 0.12, 0.85, P["trim"], bevel=0.06); o.rotation_euler.x = math.radians(-35)
            lie(0.12, 0.32, 0, 0.45, 1.3, P["dark"], "x", 16)
            B(0.3, 0.55, 0.28, 0, 0.75, 1.16, P["hull"], bevel=0.07)
            lie(0.075, 0.5, 0, 1.0, 1.3, P["steel"], "y", 14)
            bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.08, radius2=0.12, depth=0.16, location=(0, 1.22, 1.3),
                                            rotation=(-math.pi / 2, 0, 0))
            bpy.context.object.data.materials.append(P["dark"])
            sph(0.045, 0, 1.25, 1.2, P["glass"])
            pipe([(0.15, -0.05, 0.7), (0.15, 0.25, 1.15), (0.1, 0.6, 1.36), (0.05, 1.0, 1.36)], 0.03, P["rubber"])
            B(0.24, 0.04, 0.04, 0, -0.16, 0.9, P["accent"], bevel=0.0)
        elif name == "kh-flame-ring":
            # A projector housing on the ring, its nozzle out under a shroud, a fuel manifold on its back, the pilot
            # light under the nozzle.
            B(0.5, 0.6, 0.36, 0, 0.0, 0.62, P["hull"], bevel=0.08)
            lie(0.1, 0.8, 0, 0.6, 0.82, P["steel"], "y", 14)
            o = B(0.3, 0.5, 0.06, 0, 0.6, 0.96, P["trim"], bevel=0.02)
            lie(0.13, 0.08, 0, 1.0, 0.82, P["dark"], "y", 16)
            sph(0.045, 0, 1.02, 0.7, P["glass"])
            for sx in (-1, 1):
                pipe([(sx * 0.2, -0.3, 0.7), (sx * 0.22, -0.2, 1.05), (sx * 0.1, 0.1, 1.0)], 0.03, P["steel"])
        elif name == "gs-flame-arm":
            # A scrap boom: a pipe shoulder on the ring, a pipe arm raised, a clamp elbow, a flame lance level with a
            # welded tip, the igniter lit, a rubber hose taped along it, a crank wheel.
            cyl(0.26, 0.3, 0, 0.05, 0.6, P["hull"], verts=10, bevel=0.01)
            B(0.3, 0.3, 0.2, 0, -0.25, 0.65, P["accent"], bevel=0.01)
            o = B(0.18, 0.18, 0.7, 0, 0.12, 0.85, P["gunmetal"], bevel=0.01); o.rotation_euler.x = math.radians(-30)
            B(0.26, 0.3, 0.22, 0, 0.47, 1.32, P["trim"], bevel=0.01)
            lie(0.11, 0.35, 0, 0.75, 1.42, P["hull"], "y", 10)
            lie(0.055, 0.8, 0, 0.85, 1.42, P["gunmetal"], "y", 10)
            lie(0.08, 0.1, 0, 1.28, 1.42, P["dark"], "y", 10)
            sph(0.05, 0, 1.32, 1.32, P["glass"])
            pipe([(0.12, 0.0, 0.7), (0.12, 0.3, 1.2), (0.08, 0.7, 1.48), (0.05, 1.1, 1.48)], 0.03, P["rubber"])
            tor(0.12, 0.02, -0.2, 0.05, 0.8, P["steel"]).rotation_euler = (0, math.pi / 2, 0)
            o = B(0.4, 0.04, 0.3, 0, 0.6, 1.2, P["shield"], bevel=0.01); o.rotation_euler.x = math.radians(-20)
        elif name == "gs-flame-lance":
            # A tall pintle with a flame lance on it, a shield plate, a pressure bottle strapped to the pintle, the
            # igniter lit.
            cyl(0.07, 0.65, 0, 0, 0.6, P["steel"], verts=10)
            B(0.2, 0.5, 0.18, 0, 0.0, 1.2, P["trim"], bevel=0.02)
            lie(0.05, 0.9, 0, 0.65, 1.3, P["steel"], "y", 10)
            sph(0.05, 0, 1.12, 1.22, P["glass"])
            o = B(0.5, 0.04, 0.4, 0, 0.32, 1.05, P["hull"], bevel=0.01); o.rotation_euler.x = math.radians(-10)
            cyl(0.1, 0.45, 0.15, -0.1, 0.65, P["accent"], verts=14)
            pipe([(0.15, -0.1, 1.1), (0.1, 0.0, 1.3)], 0.025, P["rubber"])
    b = group(base); h = group(head)
    # (The arms on the neck's top: built from the ring at 0.6, raised to the neck's 1.4.)
    if name == "kh-flame-arm":
        for o in h:
            if o.parent is None: o.location.z += 0.3   # (onto the short neck's 0.9; 0.8 onto the old one)
    return b, h


TURRETS = {("turret", "kh"): lambda: concept("kh-laser-neck"), ("gun-turret", "kh"): lambda: concept("kh-gun-twin"),
           ("turret", "gs"): lambda: concept("gs-pintle")}


BUILD = {("fabricator", "kh"): fabricator_kh, ("fabricator", "gs"): fabricator_gs,
         ("generator", "kh"): generator_kh, ("generator", "gs"): generator_gs,
         ("radar", "kh"): radar_kh, ("radar", "gs"): radar_gs, ("drill", "kh"): drill_kh,
         ("depot", "kh-a"): depot_kh_a, ("depot", "kh-b"): depot_kh_b, ("depot", "gs-a"): depot_gs_a,
         ("depot", "gs-b"): depot_gs_b, ("launchpad", "kh-a"): launchpad_kh_a, ("launchpad", "kh-b"): launchpad_kh_b,
         ("launchpad", "gs-a"): launchpad_gs_a, ("launchpad", "gs-b"): launchpad_gs_b,
         ("depot", "kh"): depot_kh, ("depot", "gs"): depot_gs, ("launchpad", "kh"): launchpad_kh, ("launchpad", "gs"): launchpad_gs}
if WHAT == "concept":
    # Clay at two headings (south-west and north-east: k 40 and 8 of 64), base and head together, its shadow with it.
    base, head = (fconcept if "flame" in F else concept)(F)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    bpy.ops.object.empty_add(location=(0, 0, 0)); root = bpy.context.object
    for o in base + [pv]:
        if o.parent is None: o.parent = root
    k = 1.15 if "flame" in F else 1.3
    root.scale = (k, k, 1.0); bpy.context.view_layer.update()   # (wide, not tall: stretched as the game draws it, 1.1 read tall and narrow beside vanilla)
    lpkit.bevel_all(base + head, 0.02)
    ground, sun, world = lpkit.stage(scene, 3 if "flame" in F else 2, 1.9)
    lpkit.emission(P["glass"], 3.0)
    HEAD = (40, 8)
    def turn(f):
        pv.rotation_euler = (0, 0, -HEAD[f] * 2 * math.pi / 64); bpy.context.view_layer.update()
    lpkit.passes(scene, out, len(HEAD), turn, base + head, {P["light"], P["glass"]}, ground, sun, world, shadow_each=True)
    print("rendered", WHAT, F, out)
    sys.exit(0)
if WHAT == "pylon":
    # One direction (a pole's pictures and its wire points, one set), its wire tips projected to the screen (posts.json,
    # tiles from the entity's centre after the sheet's sqrt(2) stretch; and on its shadow, along the sun).
    from bpy_extras.object_utils import world_to_camera_view
    import json, mathutils as _mu
    # (Grubstake's: the welded tripod, gs-b of three clay concepts; the scrap post, gs-a, read as the bare stick the KH
    # mast's review turned down, the I-beam in drums, gs-c, busy and its drums a bollard.)
    model, tips = pylon_kh() if F == "kh" else pylon_gs_concept(F if F.startswith("gs-") else "gs-b")
    lpkit.bevel_all(model, 0.006)
    ground, sun, world = lpkit.stage(scene, 1, 2.4)
    lpkit.emission(P["light"], 3.0); lpkit.emission(P["glass"], 0.15)
    lpkit.passes(scene, out, 1, lambda f: None, model, {P["light"]}, ground, sun, world)
    span = scene.camera.data.ortho_scale
    light = sun.matrix_world.to_quaternion() @ _mu.Vector((0, 0, -1))
    pts = {"wire": {}, "shadow": {}}
    for col, wp in tips.items():
        c = world_to_camera_view(scene, scene.camera, wp)
        pts["wire"][col] = [round((c.x - 0.5) * span, 3), round(-(c.y - 0.5) * span * math.sqrt(2), 3)]
        gp = wp + light * (wp.z / max(1e-3, -light.z))
        g = world_to_camera_view(scene, scene.camera, gp)
        pts["shadow"][col] = [round((g.x - 0.5) * span, 3), round(-(g.y - 0.5) * span * math.sqrt(2), 3)]
    json.dump(pts, open(f"{out}/posts.json", "w"), indent=1)
    print("rendered", WHAT, F, out, pts)
    sys.exit(0)
if WHAT == "flamer":
    # Its base in four directions (north: its nozzle north, its inlets south), the head in 64 directions on a pivot at
    # the entity's centre (so one head serves every base direction), each without the other's shadow.
    # (The second flamers, from clay concepts: the first, flamer_kh and flamer_gs, read as a box with barrels.)
    base, head = fconcept("kh-flame-arm" if F == "kh" else "gs-flame-arm")
    base += scatter(base, {P["hull"], P["trim"]}, P["dark"], P["steel"], 9, density=8.0)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    bpy.ops.object.empty_add(location=(0, 0, 0)); rig = bpy.context.object
    for o in base:
        if o.parent is None: o.parent = rig
    # (1.15 across: at the footprint it read narrow beside vanilla's flamer, stretched as the game draws it.)
    bpy.ops.object.empty_add(location=(0, 0, 0)); root = bpy.context.object
    rig.parent = root; pv.parent = root
    root.scale = (1.15, 1.15, 1.0); bpy.context.view_layer.update()
    lpkit.bevel_all(base + head, 0.02)
    ground, sun, world = lpkit.stage(scene, 3, 2.2)
    glowing = {P["light"], P["glass"]}
    lpkit.emission(P["light"], 2.5); lpkit.emission(P["glass"], 3.0)
    for o in head: o.visible_camera = False; o.visible_shadow = False; o.hide_render = True
    for d, yaw in (("north", 0), ("east", 270), ("south", 180), ("west", 90)):
        rig.rotation_euler = (0, 0, math.radians(yaw)); bpy.context.view_layer.update()
        for o in base: o.visible_camera = True
        lpkit.passes(scene, f"{out}/base-{d}", 1, lambda f: None, base, glowing, ground, sun, world)
    for o in head: o.visible_camera = True; o.visible_shadow = True; o.hide_render = False
    for o in base: o.visible_camera = False; o.visible_shadow = False; o.hide_render = True
    N = int(os.environ.get("LP_FRAMES", 64))
    def turn(f):
        pv.rotation_euler = (0, 0, -f * 2 * math.pi / N); bpy.context.view_layer.update()
    lpkit.passes(scene, f"{out}/head", N, turn, head, glowing, ground, sun, world, shadow_each=True)
    print("rendered", WHAT, F, out)
    sys.exit(0)
if (WHAT, F) in TURRETS:
    base, head = TURRETS[(WHAT, F)]()
    base += scatter(base, {P["hull"], P["trim"]}, P["dark"], P["steel"], 7, density=8.0)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    # (At 1.1: at the footprint they stood smaller than vanilla's turrets of the same size, at 1.25 larger.)
    bpy.ops.object.empty_add(location=(0, 0, 0)); root = bpy.context.object
    for o in base + [pv]:
        if o.parent is None: o.parent = root
    root.scale = (1.3, 1.3, 1.0); bpy.context.view_layer.update()   # (wide, not tall: stretched as the game draws it, 1.1 read tall and narrow beside vanilla)
    lpkit.bevel_all(base + head, 0.02)
    ground, sun, world = lpkit.stage(scene, 2, 1.9)
    glowing = {P["light"], P["glass"]}
    # (Each part's pass without the other's shadow: hidden from the camera alone, the head had cast its shadow into the
    # base's, a ghost pointing north under every heading, and the base its own again into each of the head's.)
    # (And out of the render altogether: hidden from camera and shadow, the base still took the ambient light off the
    # ground under it, and every head frame carried a square of shadow the size of the base, solid once shadows were
    # made solid, 0.2.333, showing as a dark column beside the plate; the user: "???", 2026-11-11.)
    for o in head: o.visible_camera = False; o.visible_shadow = False; o.hide_render = True
    lpkit.emission(P["light"], 2.0)
    lpkit.passes(scene, f"{out}/base", 1, lambda f: None, base, glowing, ground, sun, world)
    for o in head: o.visible_camera = True; o.visible_shadow = True; o.hide_render = False
    for o in base: o.visible_camera = False; o.visible_shadow = False; o.hide_render = True
    N = int(os.environ.get("LP_FRAMES", 64))
    def turn(f):
        pv.rotation_euler = (0, 0, -f * 2 * math.pi / N); bpy.context.view_layer.update()
    lpkit.passes(scene, f"{out}/head", N, turn, head, glowing, ground, sun, world, shadow_each=True)
    print("rendered", WHAT, F, out)
    sys.exit(0)
FRAMES = int(os.environ.get("LP_FRAMES", 16))
TILES = {"fabricator": 3, "generator": 2, "radar": 3, "drill": 3, "depot": 4, "launchpad": 9}[WHAT]
if WHAT in ("depot", "launchpad"): FRAMES = 1   # (a container's one picture)
objs, set_frame = BUILD[(WHAT, F)]()
# (Taller, where vanilla's sprite of the same footprint stands taller: the generators read squat beside the accumulator.)
LIFT = {"generator": 1.35}.get(WHAT, 1.0)
if LIFT != 1.0:
    for o in objs:
        if o.parent is None:
            o.location.z *= LIFT; o.scale.z *= LIFT
    for o in scene.objects:
        if o.type == "EMPTY": o.location.z *= LIFT; o.scale.z *= LIFT
lpkit.bevel_all(objs)
# (A turning head: its shadow turns with it, one a frame.)
TURNS = WHAT in ("radar",)
ground, sun, world = lpkit.stage(scene, TILES, 3.2 if TURNS else 2.2)
if WHAT == "drill":
    # Four directions, the model turned whole on a rig (its chute faces the direction: north at yaw 0), each its frames.
    bpy.ops.object.empty_add(location=(0, 0, 0)); rig = bpy.context.object
    for o in objs:
        if o.parent is None: o.parent = rig
    for o in scene.objects:
        if o.type == "EMPTY" and o is not rig and o.parent is None: o.parent = rig
    for d, yaw in (("north", 0), ("east", 270), ("south", 180), ("west", 90)):
        rig.rotation_euler = (0, 0, math.radians(yaw)); bpy.context.view_layer.update()
        for o in objs: o.visible_camera = True        # (passes hides the model for its shadow and leaves it hidden)
        lpkit.passes(scene, f"{out}/{d}", FRAMES, lambda f: set_frame(f, FRAMES), objs, {P["light"], P["glass"]}, ground, sun,
                     world, shadow_each=(F == "kh"))   # (KH's ram rises and falls: its shadow with it)
else:
    lpkit.passes(scene, out, FRAMES, lambda f: set_frame(f, FRAMES), objs, {P["light"], P["glass"]}, ground, sun, world,
                 shadow_each=TURNS)
print("rendered", WHAT, F, out)
