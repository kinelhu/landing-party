"""Kessler-Hayashi's fliers (the unit pass, 2026-11-08: the user, 2026-10-23, "give Kessler the actual high tech fliers,
whereas Grubstake is a more scrappy opponent"): ducted-fan drones, against Grubstake's scrap autogyro. A slate teal and
graphite body, its fans in ducts (blurred discs inside rings: a unit's run animation holds when it stops, a modelled fan
would freeze on a hovering drone), cyan running lights, a sensor ball under its nose.
  LP_KIND=scout (lp-harrier, its light flier): a compact X of four ducts, a slim fuselage, a small gun pod.
  LP_KIND=laser (lp-laser-drone): bigger and armoured, two large side ducts, a chin emitter with a cyan lens.
Layers: the body (base), the fans (their own), the shadow of both; it hovers a tile up, its shadow on the ground.

    LP_KIND=<scout|laser> /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/kh_drone.py -- <out_dir> [N=64]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import vehicle as V
from vehicle import M, box, rod, cyl, axle_cyl

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
N = int(args[1]) if len(args) > 1 else 64
KIND = os.environ.get("LP_KIND", "scout")
V.setup()
V.kh_palette()
import lpkit
# (At 0.6 the ducts read as headlights, once their liners were open: a faint motor glow.)
M["kglow_dim"] = lpkit.mat("kglow_dim", (0.05, 0.12, 0.17), emit=(0.2, 0.5, 0.8), strength=0.12, grime=0.0)
V.GLOW_NAMES.add("kglow_dim")
M["kduct"] = lpkit.worn("kduct", (0.06, 0.07, 0.075), metal=0.45, rough=0.45, seams=3, rivets=False, wear=0.12, streaks=0.3)
H = 1.0
if os.environ.get("LP_WRECK"):
    H = 0.25                           # a wreck down on the ground

def hull(sec, y0, y1, z, m, taper=0.55, bevel=0.012):
    """A faceted body from nose (y1) to tail (y0): its cross-section sec [(x, z)...] at the middle, the ends narrowed by
    taper; four stations, so its sides slope and its nose comes to a blunt point."""
    import bmesh
    me = bpy.data.meshes.new("hull"); bm = bmesh.new()
    st = [(y0, taper * 0.8), ((2 * y0 + y1) / 3, 1.0), ((y0 + 2 * y1) / 3, 0.95), (y1, taper * 0.6)]
    rings = [[bm.verts.new((x * k, y, z + zz * (0.7 + 0.3 * k))) for x, zz in sec] for y, k in st]
    for a, b in zip(rings, rings[1:]):
        for k in range(len(sec)):
            bm.faces.new((a[k], a[(k + 1) % len(sec)], b[(k + 1) % len(sec)], b[k]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("hull", me); V.scene.collection.objects.link(o); me.materials.append(m)
    md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    return o

SEC = [(-1, -0.4), (-0.8, 0.5), (-0.3, 0.9), (0.3, 0.9), (0.8, 0.5), (1, -0.4), (0.5, -0.9), (-0.5, -0.9)]

def duct(x, y, z, r, tilt=0.0):
    """A fan duct (fat rings read as inner tubes, the first): a thin shell spun from its section, a lip at its mouth,
    teal outside and graphite inside, three thin struts, a hub, a running light on its rim."""
    h = r * 0.45
    import bmesh
    prof = [(r, -h / 2), (r, h / 2), (r + 0.02, h / 2 + 0.012), (r + 0.045, h / 2), (r + 0.04, -h / 2)]
    me = bpy.data.meshes.new("duct"); bm = bmesh.new()
    vs = [bm.verts.new((rr, 0, zz)) for rr, zz in prof]
    for k in range(len(vs)): bm.edges.new((vs[k], vs[(k + 1) % len(vs)]))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=48, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("duct", me); V.scene.collection.objects.link(o); o.location = (x, y, z)
    me.materials.append(M["kduct"])                        # (teal and pale, the ducts outshone the bodies, the second;
    # their lips are all edge, and the worn edge's bare metal made pale rings: a finish with little wear)
    # (Its liner open at both ends: a capped cylinder's lids hid the glow inside.)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=r - 0.003, depth=h * 0.9, location=(x, y, z), end_fill_type="NOTHING")
    o = V.obj(); o.data.materials.append(M["kdark"])
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.004
    for k in range(3):
        a = k * 2 * math.pi / 3
        rod((x, y, z - h * 0.2), (x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.95, z - h * 0.2), 0.006, M["kdark"])
    cyl(r * 0.18, h * 0.6, x, y, z - h * 0.3, M["kpaint2"], bevel=0.006)
    # A faint cyan glow in the duct's throat, its motor's (dark, the ducts read as empty black rings at game scale).
    bpy.ops.mesh.primitive_torus_add(major_radius=r * 0.92, minor_radius=0.006, location=(x, y, z - h * 0.3), major_segments=48, minor_segments=6)
    V.obj().data.materials.append(M["kglow_soft"])
    cyl(r * 0.7, 0.003, x, y, z - h * 0.42, M["kglow_dim"])
    cyl(0.01, 0.004, x + r + 0.04, y, z + h / 2 + 0.004, M["kglow"])

FANS = []
def fan(x, y, z, r):
    FANS.append((x, y, z, r))

def body():
    if KIND == "scout":
        # A slim faceted fuselage, a canopy over its sensors, four ducts on swept arms, a gun pod under it.
        hull([(x * 0.16, z * 0.11) for x, z in SEC], -0.44, 0.46, H - 0.04, M["kpaint"])
        hull([(x * 0.07, z * 0.045) for x, z in SEC], 0.04, 0.32, H + 0.06, M["glass"], taper=0.5, bevel=0.006)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            x, y = math.cos(a) * 0.36, math.sin(a) * 0.36
            rod((math.cos(a) * 0.06, math.sin(a) * 0.06, H - 0.02), (x * 0.78, y * 0.78, H), 0.022, M["kpaint2"])
            duct(x, y, H, 0.105); fan(x, y, H, 0.105)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(0, 0.26, H - 0.1), segments=32, ring_count=16)
        V.obj().data.materials.append(M["kgraph"])
        cyl(0.022, 0.004, 0, 0.3, H - 0.1, M["glass"], rot=(math.pi / 2, 0, 0))
        rod((0.0, 0.0, H - 0.1), (0.0, 0.42, H - 0.11), 0.014, M["kdark"])                        # gun pod's barrel
        hull([(x * 0.03, z * 0.025) for x, z in SEC], -0.06, 0.16, H - 0.1, M["kgraph"], taper=0.6, bevel=0.005)
        box(0.08, 0.04, 0.004, 0, -0.18, H + 0.035, M["kwhite"], bevel=0.0)
        cyl(0.01, 0.004, 0, -0.33, H - 0.02, M["tail"])
    else:
        # The laser drone: a broad faceted lifting body, armour plates over it, two big side ducts on stub wings, a chin
        # emitter, a dorsal sensor fin.
        hull([(x * 0.29, z * 0.13) for x, z in SEC], -0.38, 0.42, H - 0.06, M["kpaint"], taper=0.5, bevel=0.015)
        hull([(x * 0.17, z * 0.06) for x, z in SEC], -0.24, 0.22, H + 0.08, M["kpaint2"], taper=0.6, bevel=0.01)
        for sx in (-1, 1):
            V.panel([(sx * 0.18, -0.12, H - 0.02), (sx * 0.18, 0.14, H - 0.02), (sx * 0.4, 0.08, H), (sx * 0.4, -0.08, H)],
                    M["kgraph"], t=0.025, bevel=0.008)
            duct(sx * 0.48, 0.0, H, 0.15); fan(sx * 0.48, 0.0, H, 0.15)
        for sy in (-1, 1):
            duct(0, sy * 0.42, H + 0.04, 0.065); fan(0, sy * 0.42, H + 0.04, 0.065)
        box(0.14, 0.12, 0.08, 0, 0.24, H - 0.16, M["kgraph"], bevel=0.03)
        rod((0, 0.28, H - 0.13), (0, 0.42, H - 0.13), 0.045, M["kdark"])
        bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.011, location=(0, 0.43, H - 0.13), rotation=(math.pi / 2, 0, 0),
                                         major_segments=32, minor_segments=8)
        V.obj().data.materials.append(M["steel"])
        cyl(0.036, 0.006, 0, 0.432, H - 0.13, M["kglow"], rot=(math.pi / 2, 0, 0))
        V.panel([(0, -0.08, H + 0.1), (0, -0.28, H + 0.08), (0, -0.3, H + 0.24)], M["kgraph"], t=0.018)
        for sx in (-1, 1):
            cyl(0.012, 0.004, sx * 0.14, 0.22, H + 0.03, M["kglow"])
        box(0.14, 0.07, 0.005, 0, -0.1, H + 0.115, M["kwhite"], bevel=0.0)

def fans():
    for x, y, z, r in FANS:
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=r * 0.86, depth=0.004, location=(x, y, z + 0.005))
        V.obj().data.materials.append(V.blur_mat("fan", (0.06, 0.065, 0.07), 0.18, streaks=3.0))

base = V.group(body)
modules = {"fans": V.group(fans)}
V.finish(grime=0.4, mud=0.0)
# LP_WRECK=1: its wreck (4 directions, its shadow in the picture; the fans gone), then stop.
if os.environ.get("LP_WRECK"):
    for o in modules["fans"]: o.hide_render = True
    V.wreck(base, out, seed=23, tilt=(10, -12), sink=0.03, tiles=2, margin=1.0, scorch=0.75, soot=0.5, fade=0.55)
    # (A tank's soot under it, the first: a hard dark oval round a small flier. A faint smudge where it fell.)
    print("kh drone wreck to", out); sys.exit(0)
rig = V.light(2, 2.2)
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, light_rig=rig)
print("kh drone", KIND + ":", N, "directions to", out)
