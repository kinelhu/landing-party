"""The factions' working buildings, modelled (phase 2 of the graphics pass; the user, 2026-11-10: "I still see some gross
recolors. Why not use blender again?"; the landers alone keep their repaint): each building a role, Kessler-Hayashi's and
Grubstake's builds of it apart, KH clean corporate blue-grey with cyan lights, Grubstake patched ochre scrap with amber
(palette() in faction_buildings.py; ochre lpkit's grimed paint).
  fabricator  3x3, the parts maker: KH a sealed fab module, a print gantry crossing under its glazed roof; Grubstake an
              open scrap press, its ram stamping (16 frames: its working animation).

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
        # (The player buildings' Kessler-Hayashi blue, at their texture scale: at 0.8 it read as pale concrete.)
        hull = lptex.textured("kh-hull", "PaintedMetal006", hue=0.62, sat=0.65, val=0.62, scale=2.5, edge=(0.5, 0.52, 0.55)) if TEX \
            else lpkit.worn("kh-hull", (0.12, 0.17, 0.24), metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.25)
        trim = lpkit.worn("kh-trim", (0.42, 0.43, 0.42), metal=0.3, rough=0.5, seams=2, rivets=False, wear=0.3)
        accent = lpkit.worn("kh-haz", (0.62, 0.5, 0.1), metal=0.2, rough=0.6, seams=8, rivets=False, wear=0.3)
        light = lpkit.mat("kh-light", (0.2, 0.5, 0.6), metal=0.2, rough=0.3, emit=(0.45, 0.85, 1.0), strength=0.0, grime=0.0)
        glass = lpkit.mat("kh-glass", (0.02, 0.035, 0.045), metal=0.6, rough=0.12, emit=(0.3, 0.7, 0.9), strength=0.0, grime=0.0)
    else:
        hull = lpkit.mat("gs-hull", (0.3, 0.18, 0.045), metal=0.3, rough=0.65, grime=0.85)
        trim = lptex.textured("gs-rust", "MetalPlates013", val=0.6, scale=0.8, edge=(0.4, 0.33, 0.25)) if TEX \
            else lpkit.worn("gs-rust", (0.25, 0.11, 0.05), metal=0.5, rough=0.7, seams=6)
        accent = lpkit.worn("gs-red", (0.22, 0.07, 0.04), metal=0.3, rough=0.7, seams=6, rivets=True, wear=0.7)
        light = lpkit.mat("gs-light", (0.6, 0.4, 0.05), metal=0.1, rough=0.3, emit=(1.0, 0.62, 0.15), strength=0.0, grime=0.0)
        glass = lpkit.mat("gs-glass", (0.08, 0.06, 0.03), metal=0.1, rough=0.2, emit=(1.0, 0.55, 0.15), strength=0.0, grime=0.0)
    P = {"hull": hull, "trim": trim, "dark": W["dark"], "steel": W["steel"], "accent": accent, "light": light,
         "glass": glass, "rubber": W["rubber"], "hazard": W["hazard"]}
    if CLAY:
        clay = lpkit.mat("clay", (0.5, 0.5, 0.5), metal=0.0, rough=0.7, grime=0.0)
        P = {k: (v if k in ("light", "glass") else clay) for k, v in P.items()}
    return P


P = palette(F)


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


BUILD = {("fabricator", "kh"): fabricator_kh, ("fabricator", "gs"): fabricator_gs}
FRAMES = int(os.environ.get("LP_FRAMES", 16))
TILES = {"fabricator": 3}[WHAT]
objs, set_frame = BUILD[(WHAT, F)]()
lpkit.bevel_all(objs)
ground, sun, world = lpkit.stage(scene, TILES, 2.2)
lpkit.passes(scene, out, FRAMES, lambda f: set_frame(f, FRAMES), objs, {P["light"], P["glass"]}, ground, sun, world)
print("rendered", WHAT, F, out)
