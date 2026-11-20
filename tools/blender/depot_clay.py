"""Clay candidates for the player's supply depot (lp-supply-depot, still vanilla's requester chest re-tinted): phase 1, four
silhouettes to choose from, not wired into the mod. Grey clay, a dark clay base, and the one saturated element each would
carry tinted so its place reads (hazard yellow, an amber lamp, brass rounds). One direction, the kit's camera and sun, one
render a candidate with its shadow on the catcher.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/depot_clay.py -- <out dir> [a b c d]
    then: uv run --with pillow python tools/blender/depot_clay_sheet.py <out dir> <composite dir>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = set(args[1:])
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
lpkit.gpu(scene)
B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere


def clay(name, rgb, rough=0.65, emit=None, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = 3.0
    return m


CLAY = clay("clay", (0.26, 0.26, 0.26))
DARKC = clay("clay-dark", (0.06, 0.06, 0.065))
MIDC = clay("clay-mid", (0.13, 0.13, 0.13))
HAZ = clay("haz", (0.75, 0.55, 0.06))
AMBER = clay("amber", (0.7, 0.45, 0.08), 0.3, emit=(1.0, 0.6, 0.15))
BRASS = clay("brass", (0.62, 0.42, 0.14), 0.35, metal=0.8)


def bevel(o, w=0.02, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"; return o


def frustum(bx, by, tx, ty, h, x, y, z, m, top_dy=0.0):
    """A box whose top is smaller than its foot (sloped armour), the top shifted top_dy north."""
    bm = bmesh.new()
    vs = [bm.verts.new((sx * bx / 2, sy * by / 2, 0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    vt = [bm.verts.new((sx * tx / 2, sy * ty / 2 + top_dy, h)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(vs[::-1]); bm.faces.new(vt)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((vs[i], vs[j], vt[j], vt[i]))
    me = bpy.data.meshes.new("frustum"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("frustum", me); scene.collection.objects.link(o)
    o.location = (x, y, z); me.materials.append(m)
    return bevel(o, 0.025)


def stripes(w, d, h, x, y, z, n, along_x=True):
    """A hazard band: n alternating yellow and dark blocks."""
    for k in range(n):
        m = HAZ if k % 2 == 0 else DARKC
        if along_x:
            B(w / n, d, h, x - w / 2 + w / n * (k + 0.5), y, z, m, bevel=0.0)
        else:
            B(w, d / n, h, x, y - d / 2 + d / n * (k + 0.5), z, m, bevel=0.0)


def lamp(x, y, z, r=0.05):
    cyl(r * 1.1, 0.03, x, y, z, DARKC, verts=12)
    sph(r, x, y, z + 0.03 + r * 0.7, AMBER)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        rod((x + math.cos(a) * r * 1.15, y + math.sin(a) * r * 1.15, z + 0.03), (x + math.cos(a) * r * 1.15, y + math.sin(a) * r * 1.15, z + 0.04 + r * 1.6), 0.006, DARKC, verts=5)
    cyl(r * 1.2, 0.015, x, y, z + 0.04 + r * 1.6, DARKC, verts=12)


def top_hatch(cx, cy, z, w, d, m=CLAY, open_=0.0):
    """A robot hatch: a raised dark frame, two leaves (split east-west), hinge bars."""
    bevel(B(w + 0.06, d + 0.06, 0.04, cx, cy, z, DARKC), 0.01)
    for s in (-1, 1):
        leaf = B(w / 2 - 0.01, d, 0.025, cx + s * (w / 4 + 0.005), cy, z + 0.04, m, bevel=0.006)
        if open_:
            leaf.rotation_euler = (0, s * -open_, 0)
        rod((cx + s * (w / 2 - 0.01), cy - d / 2, z + 0.05), (cx + s * (w / 2 - 0.01), cy + d / 2, z + 0.05), 0.012, DARKC, verts=6)


# --- The candidates (1 tile: x, y in -0.5..0.5; south, the camera's side, is -y) -------------------------------------

def a_magazine():
    # A squat armoured magazine: sloped armour on a dark plinth, a robot hatch in its roof, a hazard band round the
    # plinth, lifting lugs, an amber lamp on a post at the back corner. Reads as a heavy steel box built to take a hit.
    bevel(B(0.98, 0.98, 0.07, 0, 0, 0, DARKC), 0.01)
    stripes(0.98, 0.03, 0.075, 0, -0.475, 0, 10)
    stripes(0.03, 0.98, 0.075, 0.475, 0, 0, 10, along_x=False)
    stripes(0.03, 0.98, 0.075, -0.475, 0, 0, 10, along_x=False)
    frustum(0.9, 0.86, 0.68, 0.64, 0.42, 0, 0.0, 0.07, CLAY, top_dy=0.03)
    # Armour seams down the slopes, a heavy belt at mid height.
    frustum(0.86, 0.82, 0.8, 0.76, 0.06, 0, 0.0, 0.18, MIDC)
    for x in (-0.22, 0.22):
        rod((x, -0.43, 0.07), (x * 0.82, -0.29, 0.49), 0.012, DARKC, verts=6)
    top_hatch(0, 0.03, 0.49, 0.44, 0.4)
    for sx in (-1, 1):
        lpkit.torus(0.035, 0.012, sx * 0.4, -0.05, 0.36, DARKC).rotation_euler = (0, math.pi / 2, 0)
    rod((0.36, 0.34, 0.49), (0.36, 0.34, 0.78), 0.018, DARKC, verts=8)
    lamp(0.36, 0.34, 0.78)
    # A stencil plate on its front slope.
    B(0.3, 0.02, 0.1, 0, -0.38, 0.27, DARKC, bevel=0.0).rotation_euler = (math.radians(-28), 0, 0)


def b_shell_rack():
    # A shell rack round a magazine: a dark skid, a crown of big brass rounds standing in a cradle along the back and
    # the sides, a hatch-topped magazine in the middle the robots drop into, a hazard step at the open front. The
    # rounds say ammunition at a glance; the brass is its one saturated element.
    bevel(B(0.96, 0.96, 0.08, 0, 0, 0, DARKC), 0.01)
    stripes(0.5, 0.2, 0.03, 0, -0.38, 0.08, 6)
    bevel(B(0.46, 0.44, 0.32, 0, -0.04, 0.08, CLAY), 0.03)
    top_hatch(0, -0.04, 0.4, 0.32, 0.3)
    # The cradle: two rails at two heights round three sides.
    for z in (0.16, 0.36):
        rod((-0.42, -0.36, z), (-0.42, 0.42, z), 0.018, DARKC, verts=6)
        rod((-0.42, 0.42, z), (0.42, 0.42, z), 0.018, DARKC, verts=6)
        rod((0.42, 0.42, z), (0.42, -0.36, z), 0.018, DARKC, verts=6)
    for (x, y) in ((-0.42, -0.36), (-0.42, 0.42), (0.42, 0.42), (0.42, -0.36)):
        rod((x, y, 0.08), (x, y, 0.42), 0.022, DARKC, verts=6)

    def round_(x, y, r=0.062, h=0.34):
        cyl(r * 1.08, 0.03, x, y, 0.08, BRASS, verts=16)
        cyl(r, h, x, y, 0.08, BRASS, verts=16)
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r, radius2=0.012, depth=r * 2.4, location=(x, y, 0.08 + h + r * 1.2))
        bpy.context.object.data.materials.append(DARKC)
        cyl(r * 1.01, 0.025, x, y, 0.08 + h - 0.06, DARKC, verts=16)
    for k in range(6):
        round_(-0.34 + k * 0.136, 0.33, h=0.38 if k % 2 else 0.34)
    for k in range(4):
        round_(-0.34, 0.19 - k * 0.135)
        round_(0.34, 0.19 - k * 0.135)
    lamp(0.0, 0.2, 0.4, r=0.04)


def c_locker():
    # An upright ammunition locker: a tall armoured cabinet on a dark plinth, its double doors with a hazard bar across,
    # louvres, a hooded roof with a robot hatch, an amber lamp on the roof, two ammunition cans by its foot. The
    # tallest of the four: a locker shape, vertical against the chests round it.
    bevel(B(0.96, 0.84, 0.07, 0, 0.02, 0, DARKC), 0.01)
    bevel(B(0.7, 0.5, 0.82, 0, 0.12, 0.07, CLAY), 0.03)
    # Doors: a seam, two handles, a louvre block each, the hazard bar.
    B(0.012, 0.02, 0.74, 0, -0.135, 0.11, DARKC, bevel=0.0)
    for s in (-1, 1):
        B(0.025, 0.03, 0.14, s * 0.05, -0.145, 0.42, DARKC, bevel=0.0)
        for k in range(4):
            B(0.22, 0.03, 0.018, s * 0.19, -0.14, 0.62 + k * 0.045, DARKC, bevel=0.0)
    stripes(0.7, 0.02, 0.07, 0, -0.14, 0.2, 8)
    # The hood: an overhanging roof, and the robot hatch raised on it.
    bevel(B(0.8, 0.62, 0.06, 0, 0.1, 0.89, MIDC), 0.02)
    bevel(B(0.4, 0.34, 0.08, 0, 0.12, 0.95, CLAY), 0.02)
    top_hatch(0, 0.12, 1.03, 0.3, 0.26)
    lamp(0.3, 0.3, 0.95, r=0.045)
    # Two ammunition cans at its foot, a handle each.
    for (x, y, yaw) in ((-0.33, -0.3, 0.2), (0.32, -0.28, -0.35)):
        c = bevel(B(0.2, 0.12, 0.15, x, y, 0.07, MIDC, rot=yaw), 0.015)
        rod((x - 0.05, y, 0.25), (x + 0.05, y, 0.25), 0.01, DARKC, verts=5).rotation_euler = (0, 0, yaw)
        B(0.16, 0.13, 0.025, x, y, 0.2, DARKC, rot=yaw, bevel=0.0)


def d_drum():
    # A round armoured magazine: a ribbed drum on a square dark base, a shallow dome with an iris hatch the robots drop
    # through, a hazard band round its foot, a feed chute out the front for inserters, an amber lamp on the dome's rim.
    bevel(B(0.98, 0.98, 0.07, 0, 0, 0, DARKC), 0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B(0.14, 0.14, 0.04, sx * 0.4, sy * 0.4, 0.07, MIDC, bevel=0.01)
    # The hazard band: alternating segments round the drum's foot.
    n = 16
    bm = bmesh.new()
    me = bpy.data.meshes.new("band")
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        r0, r1 = 0.415, 0.43
        ring = []
        for a in (a0, a1):
            for r in (r0, r1):
                for z in (0.07, 0.16):
                    ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        bmesh.ops.convex_hull(bm, input=ring)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("band", me); scene.collection.objects.link(o)
    me.materials.append(HAZ); me.materials.append(DARKC)
    for p in me.polygons:
        c = p.center; a = math.atan2(c.y, c.x) % (2 * math.pi)
        p.material_index = int(a / (2 * math.pi) * n) % 2
    cyl(0.41, 0.46, 0, 0, 0.07, CLAY, verts=48)
    for z in (0.22, 0.36, 0.5):
        lpkit.torus(0.415, 0.016, 0, 0, z, MIDC)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.41, location=(0, 0, 0.53), segments=48, ring_count=24)
    dome = bpy.context.object; dome.scale = (1, 1, 0.32); dome.data.materials.append(CLAY)
    # The iris hatch: a dark collar, six leaves meeting at the centre.
    cyl(0.17, 0.05, 0, 0, 0.62, DARKC, verts=32)
    for k in range(6):
        a = k * math.pi / 3
        bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=0.15, depth=0.02, location=(math.cos(a) * 0.04, math.sin(a) * 0.04, 0.68),
                                            rotation=(0, 0, a))
        bpy.context.object.data.materials.append(CLAY if k % 2 else MIDC)
    # The feed chute: a sloped box out the front-right, its flap.
    ch = bevel(B(0.18, 0.28, 0.12, 0.2, -0.36, 0.2, MIDC), 0.015); ch.rotation_euler = (math.radians(-20), 0, 0)
    B(0.16, 0.02, 0.1, 0.2, -0.5, 0.15, DARKC, bevel=0.0)
    lamp(-0.25, 0.22, 0.62, r=0.045)


MODELS = {"a": a_magazine, "b": b_shell_rack, "c": c_locker, "d": d_drum}
ground, sun, world = lpkit.stage(scene, 1, 1)
sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.38
os.makedirs(out, exist_ok=True)
for name, fn in MODELS.items():
    if only and name not in only:
        continue
    before = set(scene.objects)
    fn()
    model = [o for o in scene.objects if o not in before]
    ground.hide_render = False
    lpkit.render(scene, f"{out}/{name}.png")
    print("rendered", name)
    for o in model:
        bpy.data.objects.remove(o, do_unlink=True)
