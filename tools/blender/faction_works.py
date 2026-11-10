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
  pylon       1x1, one direction and its wire points (posts.json): KH a composite mast, Grubstake a scrap pole.
  turret      2x2, a base once and a head in 64 directions (north first, clockwise): KH's laser turret (a lens turret on
              a hexagonal ring) and gun-turret (twin autocannon), Grubstake's turret (a gun nest of scrap, one barrel).
  generator   2x2, the camp's power: KH a fusion cell, its core lit, vanes turning on its crown; Grubstake a scrap
              genset, its radiator fan turning (16 frames, always running).

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
    model = group(build)
    collar = group(build_collar)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in collar:
        o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    model += scatter(model, {P["hull"], P["trim"]}, P["dark"], P["steel"], 8, density=9.0)
    def set_frame(f, frames):
        t = f / frames
        pv.rotation_euler = (0, 0, t * math.pi / 4)
        lpkit.emission(P["glass"], 0.45 + 0.25 * math.sin(t * 4 * math.pi))
        lpkit.emission(P["light"], 3.0 if (f % 4) < 2 else 1.2)
        bpy.context.view_layer.update()
    return model + collar, set_frame


def pylon_kh():
    """A composite mast: a dark foot, a tapered blue-grey shaft banded, a crossarm with three insulator stacks (the
    copper wire at the middle one's tip, the circuit wires at the arm's ends), a cyan beacon on top."""
    import mathutils as _mu
    V = _mu.Vector
    def build():
        cyl(0.26, 0.1, 0, 0, 0, P["dark"], verts=8)
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.12, radius2=0.07, depth=2.6, location=(0, 0, 1.4))
        bpy.context.object.data.materials.append(P["hull"])
        for z in (0.5, 1.2, 1.9):
            cyl(0.115 - z * 0.02, 0.06, 0, 0, z, P["trim"], verts=12)
        B(0.7, 0.08, 0.08, 0, 0, 2.45, P["trim"], bevel=0.01)
        for x in (-0.3, 0.0, 0.3):
            for k in range(3):
                cyl(0.04, 0.035, x, 0, 2.53 + k * 0.045, P["glass"] if x == 0 else P["steel"], verts=10)
        cyl(0.05, 0.08, 0, 0, 2.7, P["dark"], verts=10)
        sph(0.045, 0, 0, 2.82, P["light"])
        B(0.14, 0.04, 0.16, 0, -0.1, 0.55, P["dark"], bevel=0.005)
        B(0.06, 0.02, 0.04, 0, -0.125, 0.65, P["light"], bevel=0.0)
    tips = {"copper": V((0, 0, 2.67)), "red": V((-0.3, 0, 2.67)), "green": V((0.3, 0, 2.67))}
    return group(build), tips


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
        lie(0.12, 0.55, 0.45, 0.4, 0.35, P["steel"], "y", 16)                      # a pressure bottle
        rod((0.45, 0.1, 0.4), (0.15, 0.1, 0.5), 0.025, P["rubber"])
        cyl(0.4, 0.08, 0, 0.25, 0.2, P["steel"], verts=12)
        for k, (x, y) in enumerate(((-0.45, 0.6), (-0.4, 0.95))):
            B(0.25, 0.2, 0.15, x, y, 0.2, P["trim"] if k else P["accent"], rot=0.3 * k, bevel=0.005)
    def head():
        cyl(0.3, 0.12, 0, 0, 0.28, P["dark"], verts=12)
        B(0.45, 0.5, 0.3, 0, -0.05, 0.4, P["hull"], bevel=0.01)
        o = B(0.6, 0.05, 0.38, 0, 0.25, 0.38, P["trim"], bevel=0.005); o.rotation_euler.x = math.radians(-10)
        lie(0.05, 0.85, 0, 0.6, 0.58, P["steel"], "y", 12)
        lie(0.08, 0.1, 0, 1.0, 0.58, P["dark"], "y", 12)
        sph(0.04, 0.0, 1.05, 0.5, P["light"])
        rod((0.15, -0.2, 0.55), (0.05, 0.3, 0.6), 0.025, P["rubber"])
    return group(base), group(head)


TURRETS = {("turret", "kh"): turret_kh_laser, ("gun-turret", "kh"): turret_kh_gun, ("turret", "gs"): turret_gs}


BUILD = {("fabricator", "kh"): fabricator_kh, ("fabricator", "gs"): fabricator_gs,
         ("generator", "kh"): generator_kh, ("generator", "gs"): generator_gs,
         ("radar", "kh"): radar_kh, ("radar", "gs"): radar_gs, ("drill", "kh"): drill_kh}
if WHAT == "pylon":
    # One direction (a pole's pictures and its wire points, one set), its wire tips projected to the screen (posts.json,
    # tiles from the entity's centre after the sheet's sqrt(2) stretch; and on its shadow, along the sun).
    from bpy_extras.object_utils import world_to_camera_view
    import json, mathutils as _mu
    model, tips = (pylon_kh if F == "kh" else pylon_gs)()
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
    base, head = (flamer_kh if F == "kh" else flamer_gs)()
    base += scatter(base, {P["hull"], P["trim"]}, P["dark"], P["steel"], 9, density=8.0)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pv = bpy.context.object
    for o in head:
        if o.parent is None:
            o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    bpy.ops.object.empty_add(location=(0, 0, 0)); rig = bpy.context.object
    for o in base:
        if o.parent is None: o.parent = rig
    lpkit.bevel_all(base + head)
    ground, sun, world = lpkit.stage(scene, 3, 1.6)
    glowing = {P["light"], P["glass"]}
    lpkit.emission(P["light"], 2.5); lpkit.emission(P["glass"], 2.0)
    for o in head: o.visible_camera = False; o.visible_shadow = False
    for d, yaw in (("north", 0), ("east", 270), ("south", 180), ("west", 90)):
        rig.rotation_euler = (0, 0, math.radians(yaw)); bpy.context.view_layer.update()
        for o in base: o.visible_camera = True
        lpkit.passes(scene, f"{out}/base-{d}", 1, lambda f: None, base, glowing, ground, sun, world)
    for o in head: o.visible_camera = True; o.visible_shadow = True
    for o in base: o.visible_camera = False; o.visible_shadow = False
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
    # (At 1.25: first rendered at the footprint, they stood a quarter smaller than vanilla's turrets of the same size.)
    bpy.ops.object.empty_add(location=(0, 0, 0)); root = bpy.context.object
    for o in base + [pv]:
        if o.parent is None: o.parent = root
    root.scale = (1.25, 1.25, 1.25); bpy.context.view_layer.update()
    lpkit.bevel_all(base + head)
    ground, sun, world = lpkit.stage(scene, 2, 1.9)
    glowing = {P["light"], P["glass"]}
    # (Each part's pass without the other's shadow: hidden from the camera alone, the head had cast its shadow into the
    # base's, a ghost pointing north under every heading, and the base its own again into each of the head's.)
    for o in head: o.visible_camera = False; o.visible_shadow = False
    lpkit.emission(P["light"], 2.0)
    lpkit.passes(scene, f"{out}/base", 1, lambda f: None, base, glowing, ground, sun, world)
    for o in head: o.visible_camera = True; o.visible_shadow = True
    for o in base: o.visible_camera = False; o.visible_shadow = False
    N = int(os.environ.get("LP_FRAMES", 64))
    def turn(f):
        pv.rotation_euler = (0, 0, -f * 2 * math.pi / N); bpy.context.view_layer.update()
    lpkit.passes(scene, f"{out}/head", N, turn, head, glowing, ground, sun, world, shadow_each=True)
    print("rendered", WHAT, F, out)
    sys.exit(0)
FRAMES = int(os.environ.get("LP_FRAMES", 16))
TILES = {"fabricator": 3, "generator": 2, "radar": 3, "drill": 3}[WHAT]
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
                     world)
else:
    lpkit.passes(scene, out, FRAMES, lambda f: set_frame(f, FRAMES), objs, {P["light"], P["glass"]}, ground, sun, world,
                 shadow_each=TURNS)
print("rendered", WHAT, F, out)
