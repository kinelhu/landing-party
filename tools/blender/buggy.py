"""Grubstake's buggy, modelled and rendered for a unit's run animation (the unit pass, 2026-11-08: the user, "starting with
units is probably preferable"; one silhouette a role, the faction's dress on it). A scrap raider built from what was to
hand, and lopsided for it (the user on the first render: "Needs much more detail and asymmetry. Wheels look bad compared
to vanilla buggy"): a tube roll cage on an open chassis; four wheels with rounded, lugged, dusty tyres, dished rims and
coil springs to the chassis; the engine bare at the back, finned, belted and hosed, one tall stack on the left and an
intake on the right; plates of four kinds (amber paint, rust, bare steel, a corrugated sheet), patched and bolted where
they fit; a fuel drum on one flank; a bull bar and winch; a shielded machine gun on a pintle; a searchlight on one
corner of the cage, a radio whip with a rag on another; a spare wheel, a shovel, rope and crates.
N directions (north first, clockwise), one frame each: body, glow (the lamps), and a shadow a direction.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/buggy.py -- <out_dir> [N=64]
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/grubstake/buggy [preview.gif]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import mathutils
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
N = int(args[1]) if len(args) > 1 else 64
scene = lpkit.reset()
# (The user, 2026-11-08: "too polygonal again": flat-shaded primitives with 8-sided tubes showed every facet. Tubes and
# cylinders get more sides here, hex nuts keep six; and every mesh is shaded smooth below, sharp edges kept by angle.)
_rod, _cyl = lpkit.rod, lpkit.cyl
lpkit.rod = lambda p0, p1, r, m, verts=8: _rod(p0, p1, r, m, verts=max(verts, 16))
lpkit.cyl = lambda r, h, x, y, z, m, verts=24, bevel=0.0, rot=(0, 0, 0): _cyl(r, h, x, y, z, m, verts=verts if verts == 6 else max(verts, 32), bevel=bevel, rot=rot)
scene.cycles.samples = 64
P = lpkit.palette_worn()
amber = lpkit.worn("amber", (0.55, 0.33, 0.1), metal=0.25, rough=0.62, seams=5, wear=0.8)
rust = lpkit.worn("rust", (0.3, 0.13, 0.06), metal=0.15, rough=0.85, seams=7, wear=0.3, streaks=0.9)
# Bare metal bright and shiny: beside vanilla's car (bright, near-white metal) the first renders had half its contrast and
# no highlights (measured: lightness 10th to 90th percentile 0.10 to 0.43 against the car's 0.02 to 0.62).
# (Fully metallic they mirrored the dim sky and stayed dark: lit by the sun instead, half metallic.)
P["steel"] = lpkit.worn("steel_b", (0.55, 0.55, 0.52), metal=0.35, rough=0.3, seams=4, rivets=False, wear=0.6)
tube = lpkit.worn("tube", (0.48, 0.47, 0.44), metal=0.35, rough=0.32, seams=3, rivets=False, wear=0.7)
canvas = lpkit.worn("canvas", (0.28, 0.25, 0.17), metal=0.0, rough=0.95, seams=10, rivets=False, wear=0.1)
olive = lpkit.worn("olive", (0.17, 0.19, 0.1), metal=0.2, rough=0.7, seams=6, wear=0.6)
bright = lpkit.mat("bright", (0.85, 0.85, 0.8), metal=0.4, rough=0.2, grime=0.2)
spring = lpkit.mat("spring", (0.7, 0.5, 0.08), metal=0.6, rough=0.4, grime=0.3)
# Tyres: dark rubber with dust on their edges (vanilla's car reads by its pale, dusty tread).
# (worn() took every lug for an edge and greyed the whole tyre, the third render: plain rubber for the body, the dust on
# the lugs alone.)
tyre = lpkit.mat("tyre", (0.022, 0.021, 0.02), metal=0.0, rough=0.85, grime=0.3)
dust = lpkit.mat("dust", (0.03, 0.029, 0.027), metal=0.0, rough=0.95, grime=0.5)
lamp = lpkit.mat("lamp", (1.0, 0.85, 0.55), emit=(1.0, 0.8, 0.45), strength=4.0, grime=0.0)
tail = lpkit.mat("tail", (0.8, 0.1, 0.05), emit=(1.0, 0.12, 0.05), strength=3.0, grime=0.0)
GLOWS = ("lamp", "tail")
rag = lpkit.mat("rag", (0.55, 0.12, 0.08), rough=0.95, grime=0.6)

before = set(scene.objects)
# Proportions in tiles, forward along +y: about the car's footprint at the buggy's 0.85 (1.3 by 1.9).
# Stretched toward a desert buggy's 2 to 1 (the user, 2026-11-08: "a little more stretched like a dune buggy, think desert
# buggy in Battlefield 2"; at 1.9 long it was 1.27 to 1 with its wheels, stubbier than vanilla's car at 1.43).
L, W, AX = 2.3, 1.18, 0.82         # length, track, axle offset from the middle
# Wheels as vanilla's car has them (the user, 2026-11-08: "too small and bright ... do it like the vanilla buggy"): about
# a third of the length across, wide, near-black rubber, dark recessed rims. (0.21 and grey lugs read small and bright.)
WR, WT = 0.28, 0.27                # wheel radius and width
ZC = 0.3                           # the chassis rails' height

def obj():
    return bpy.context.object

def oriented(kind, loc, euler, scale, m, **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(location=loc, rotation=euler, **kw)
    o = obj(); o.scale = scale; o.data.materials.append(m); return o

def axle_cyl(r, w, x, y, z, m, verts=24, bevel=0.0, segs=2):
    """A cylinder on an axis across the buggy (x), centred at (x, y, z)."""
    verts = verts if verts == 6 else max(verts, 32)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=w, location=(x, y, z), rotation=(0, math.pi / 2, 0))
    o = obj(); o.data.materials.append(m)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = segs
    return o

def coil(p0, p1, r, turns, m, wire=0.012):
    """A coil spring from p0 to p1, a true helix (rings stacked read as washers, the first close look), on its shaft."""
    a, b = mathutils.Vector(p0), mathutils.Vector(p1); d = b - a
    u = d.orthogonal().normalized(); v = d.normalized().cross(u)
    per = 20; n = turns * per
    cu = bpy.data.curves.new("coil", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = wire; cu.bevel_resolution = 3
    sp = cu.splines.new("POLY"); sp.points.add(n)
    for k in range(n + 1):
        t = k / n; ang = 2 * math.pi * k / per
        q = a + d * t + (u * math.cos(ang) + v * math.sin(ang)) * r
        sp.points[k].co = (q.x, q.y, q.z, 1)
    o = bpy.data.objects.new("coil", cu); scene.collection.objects.link(o); cu.materials.append(m)
    lpkit.rod(p0, p1, r * 0.35, P["steel"], verts=8)

def bolts(x0, y0, z, sx, sy, n=3, side="top", m=None, r=0.012):
    """Bolt heads along a plate's edges: on top (z up) at its four corners and between."""
    m = m or bright
    for i in range(n):
        f = i / (n - 1) - 0.5
        for (x, y) in ((x0 + f * sx, y0 - sy / 2 + 0.025), (x0 + f * sx, y0 + sy / 2 - 0.025)):
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=0.012, location=(x, y, z + 0.006))
            obj().data.materials.append(m)

# Rubber barely shines (its sheen under the strong sun made the tread a grey band, the first pneumatic render).
for m in (tyre, dust):
    m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.12
rim_m = lpkit.worn("rim", (0.2, 0.2, 0.19), metal=0.6, rough=0.4, seams=3, rivets=False, wear=0.7)
def spun(profile, x, y, m, steps=48, a0=None, a1=None):
    """A solid of revolution about the axle (x): profile is (axial offset, radius) points, a closed outline; swept all
    round, or from a0 to a1 (degrees from the front, +y, over the top) with its ends capped."""
    import bmesh
    me = bpy.data.meshes.new("spun"); bm = bmesh.new()
    t0 = 0.0 if a0 is None else math.radians(a0 - 90)                          # the spin's own angle: 0 at the top
    vs = [bm.verts.new((a, -r * math.sin(t0), r * math.cos(t0))) for a, r in profile]
    es = [bm.edges.new((vs[k], vs[(k + 1) % len(vs)])) for k in range(len(vs))]
    if a0 is not None:
        bm.faces.new(vs)
    sweep = 2 * math.pi if a0 is None else math.radians(a1 - a0)            # (a turn about +x carries +y up to +z)
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], cent=(0, 0, 0), axis=(1, 0, 0), angle=sweep,
                   steps=steps, use_merge=a0 is None)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for f in me.polygons: f.use_smooth = True
    o = bpy.data.objects.new("spun", me); scene.collection.objects.link(o); o.location = (x, y, WR); me.materials.append(m)
    return o

def wheel(x, y, side):
    """A pneumatic wheel (the user, 2026-11-08: "The outside of our wheels read like a toy. We need to model them like a
    real pneumatic, with the metal rim and bolts"): a tyre spun from its cross-section (bead on the rim, bulging
    sidewalls, round shoulders, the tread), tread blocks in two staggered rows; a steel rim barrel with a lipped flange
    each side; a disc set in from the outer face with vent holes; the hub, six hex nuts on it, a domed cap; a valve."""
    h, RR = WT / 2, WR * 0.62                                                   # half width, the rim's radius
    # The tyre's section, axial offset against radius, out round the outer sidewall, over the tread, back down.
    sec = [(-h + 0.02, RR), (-h - 0.005, RR + 0.04), (-h - 0.012, RR + 0.1), (-h - 0.006, WR - 0.06), (-h + 0.02, WR - 0.015),
           (-h + 0.06, WR), (h - 0.06, WR), (h - 0.02, WR - 0.015), (h + 0.006, WR - 0.06), (h + 0.012, RR + 0.1),
           (h + 0.005, RR + 0.04), (h - 0.02, RR)]
    spun(sec, x, y, tyre)
    n = 24
    for row, off in ((-1, 0.0), (1, 0.5)):
        for k in range(n):
            a = (k + off) * 2 * math.pi / n
            loc = (x + row * WT * 0.17, y + math.cos(a) * (WR + 0.002), WR + math.sin(a) * (WR + 0.002))
            o = oriented("cube", loc, (a - math.pi / 2, 0, 0), (WT * 0.3, 0.046, 0.018), dust, size=1)
            md = o.modifiers.new("b", "BEVEL"); md.width = 0.006; md.segments = 2
    # The rim: its barrel inside the bead, a lip at each flange.
    spun([(-h + 0.02, RR - 0.03), (-h + 0.02, RR + 0.005), (h - 0.02, RR + 0.005), (h - 0.02, RR - 0.03)], x, y, rim_m)
    for sd in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=RR + 0.004, minor_radius=0.011, location=(x + sd * (h - 0.02), y, WR),
                                         rotation=(0, math.pi / 2, 0), major_segments=40, minor_segments=8)
        obj().data.materials.append(rim_m)
    # The disc, set in from the outer face, with vent holes (dark discs) between hub and rim.
    ox = x + side * (h - 0.06)
    axle_cyl(RR - 0.01, 0.012, ox, y, WR, rim_m, verts=40)
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        axle_cyl(0.022, 0.014, ox + side * 0.001, y + math.cos(a) * RR * 0.66, WR + math.sin(a) * RR * 0.66, P["dark"], verts=12)
    # The hub: a boss, six hex nuts round it, a domed cap; the valve stem by the rim.
    axle_cyl(RR * 0.42, 0.04, ox + side * 0.02, y, WR, rim_m, verts=24, bevel=0.006)
    for k in range(6):
        a = k * math.pi / 3
        axle_cyl(0.013, 0.03, ox + side * 0.045, y + math.cos(a) * RR * 0.28, WR + math.sin(a) * RR * 0.28, bright, verts=6)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=RR * 0.18, location=(ox + side * 0.045, y, WR), segments=16, ring_count=8)
    o = obj(); o.scale = (0.6, 1, 1); o.data.materials.append(P["steel"])
    lpkit.rod((ox + side * 0.01, y + RR * 0.85, WR + 0.02), (ox + side * 0.045, y + RR * 0.92, WR + 0.03), 0.006, bright, verts=6)

# Fenders over the wheels, as vanilla's car has (the user, 2026-11-08): thin, over the top of the tyre, in worn steel, all
# four alike (mismatched, wide and in amber and rust they were "a little too heavy" and "draw the eye too much").
# (Pale, they read as vanilla's car at a glance, the user: "the silhouette is too much like vanilla?". On the rear wheels
# only, in Grubstake's amber: the faction's colour its mass at sprite size.)
fender_m = lpkit.worn("fender", (0.5, 0.3, 0.09), metal=0.3, rough=0.6, seams=4, rivets=False, wear=0.7)
def fender(x, y, a0=55, a1=125):          # (35 to 145 read as buckets on the stretched buggy)
    """A sheet curved over the tyre, swept smooth (nine flat boxes read "very polygonal", the user), its two edges rolled."""
    h, R = WT / 2, WR + 0.03
    sec = [(-h - 0.016, R), (-h - 0.016, R + 0.022), (-h - 0.003, R + 0.022), (-h - 0.003, R + 0.009),
           (h + 0.003, R + 0.009), (h + 0.003, R + 0.022), (h + 0.016, R + 0.022), (h + 0.016, R)]
    o = spun(sec, x, y, fender_m, steps=40, a0=a0, a1=a1)
    md = o.modifiers.new("b", "BEVEL"); md.width = 0.003; md.segments = 2
    lpkit.rod((x, y, WR + R + 0.01), (x * 0.45, y, ZC + 0.05), 0.01, tube, verts=8)
# Wheels, swing arms and springs, dune-buggy proportions (the user, 2026-11-08: vanilla's outline was four pale fenders on
# the corners): small narrow front wheels set in on bare arms, big wide rear ones under fenders; from above a wedge, narrow
# at the nose. wheel() and fender() read WR and WT, set here an axle at a time.
# (Front 0.22 by 0.18 against rear 0.3 by 0.32 read "a little too much dragster", the user: closer.)
AXLES = ((AX + 0.02, 0.98, 0.25, 0.22, False), (-AX + 0.04, 1.18, 0.28, 0.28, True))
WHEELS = []                              # (objects, hub): each wheel, for the rolling layer (LP_ONLY=wheels)
for y0, track, WR, WT, covered in AXLES:
    for sx in (-1, 1):
        x, y, sy = sx * track / 2, y0, 1 if y0 > 0 else -1
        _b4 = set(scene.objects); wheel(x, y, sx); WHEELS.append(([o for o in scene.objects if o not in _b4], (x, y, WR)))
        lpkit.rod((sx * 0.22, y - sy * 0.14, ZC), (x - sx * WT / 2, y, WR), 0.028, tube)
        lpkit.rod((sx * 0.22, y + sy * 0.1, ZC - 0.04), (x - sx * WT / 2, y, WR), 0.022, tube)
        if sy < 0:                                       # the front's are coil-overs on its frame
            coil((sx * 0.26, y - sy * 0.04, ZC + 0.22), (x - sx * WT * 0.6, y, WR + 0.04), 0.04, 7, spring)
        if covered:
            fender(x, y)

# Chassis: two rails, a floor pan, a skid plate under the front.
for sx in (-0.24, 0.24):
    lpkit.rod((sx, -L / 2 + 0.1, ZC), (sx, L / 2 - 0.12, ZC), 0.04, tube)
lpkit.box(0.56, L - 0.6, 0.04, 0, -0.05, ZC - 0.02, P["dark"], bevel=0.01)

# Front: a tube space frame, no hood (the user, 2026-11-08: "less sheet metal and more metal struts? With exposed springs"):
# lower and upper rails converging on the bull bar, cross tubes and diagonals; coil-overs from the top rails down to each
# front hub; a steering rack, its tie rods to the wheels; a skid plate under it all, a battery box, the winch. (A tapered
# nose was tried before, plain and then faceted: "squarish might have been better after all. Reads a lot like a toy".)
YF, YN = L / 2 - 0.62, L / 2 - 0.04                     # where the frame leaves the cab, the bumper
FY = AX + 0.02                                           # the front axle
for sx in (-1, 1):
    lpkit.rod((sx * 0.24, YF, ZC), (sx * 0.2, YN, 0.2), 0.03, tube)                               # lower rails
    lpkit.rod((sx * 0.34, YF, ZC + 0.12), (sx * 0.24, YN, 0.36), 0.03, tube)                      # upper rails
    lpkit.rod((sx * 0.24, YF, ZC), (sx * 0.34, YF, ZC + 0.12), 0.026, tube)
    lpkit.rod((sx * 0.22, FY, 0.25), (sx * 0.29, FY, 0.4), 0.024, tube)                           # uprights at the axle
    lpkit.rod((sx * 0.24, YF, ZC), (sx * 0.29, FY, 0.4), 0.02, tube)                              # diagonals
    lpkit.rod((sx * 0.2, YN, 0.2), (sx * 0.24, YN, 0.36), 0.026, tube)
    # The coil-over, high on the frame down to the hub: a body, its spring, the shaft.
    # (Small and high, only their tops showed, the first close look: bigger, down to an arm near the hub.)
    hub = (sx * (0.98 / 2 - 0.13), FY, 0.24)
    top = (sx * 0.26, FY - 0.04, 0.56)
    coil(top, hub, 0.058, 12, spring, wire=0.016)
    lpkit.rod(top, (top[0] + (hub[0] - top[0]) * 0.3, top[1], top[2] + (hub[2] - top[2]) * 0.3), 0.03, P["dark"], verts=12)
    # A-arms, upper and lower: two tubes each from the frame to the hub's knuckle.
    knuckle = (sx * (0.98 / 2 - 0.1), FY, 0.25)
    lpkit.box(0.04, 0.06, 0.14, knuckle[0], FY, 0.18, P["dark"], bevel=0.008)
    for dy in (-0.1, 0.1):
        lpkit.rod((sx * 0.2, FY + dy, 0.2), (knuckle[0], FY, 0.2), 0.016, tube, verts=8)
        lpkit.rod((sx * 0.25, FY + dy, 0.36), (knuckle[0], FY, 0.31), 0.014, tube, verts=8)
    lpkit.box(0.05, 0.05, 0.05, top[0], top[1], top[2] - 0.02, P["steel"], bevel=0.008)              # its mount
    lpkit.rod((sx * 0.29, FY, 0.4), top, 0.022, tube)
    lpkit.rod((sx * 0.06, FY + 0.06, 0.21), (sx * (0.98 / 2 - 0.1), FY + 0.06, 0.23), 0.012, bright, verts=6)   # tie rod
for y, z in ((YF + 0.2, ZC + 0.02), (FY, 0.4), (YN, 0.28)):
    lpkit.rod((-0.26, y, z), (0.26, y, z), 0.024, tube)                                          # cross tubes
lpkit.rod((-0.26, FY, 0.4), (0.22, YN, 0.2), 0.018, tube)                                          # a diagonal
lpkit.box(0.16, 0.06, 0.06, 0, FY + 0.06, 0.18, P["dark"], bevel=0.01)                             # steering rack
lpkit.box(0.4, 0.62, 0.02, 0, YF + 0.36, 0.12, P["dark"], bevel=0.006)                             # skid plate
lpkit.box(0.14, 0.12, 0.1, -0.1, YF + 0.16, ZC + 0.02, P["dark"], bevel=0.01)                      # battery box
lpkit.box(0.14, 0.12, 0.012, -0.1, YF + 0.16, ZC + 0.12, amber, bevel=0.004)
for x in (-0.14, -0.06):
    lpkit.cyl(0.012, 0.02, x, YF + 0.13, ZC + 0.13, bright, verts=8)
# The bull bar and the winch, as before.
for z in (0.22, 0.36):
    lpkit.rod((-0.4, L / 2 - 0.02, z), (0.4, L / 2 - 0.02, z), 0.032, tube)
for sx in (-0.34, 0.0, 0.34):
    lpkit.rod((sx, L / 2 - 0.02, 0.16), (sx, L / 2 - 0.02, 0.4), 0.026, tube)
axle_cyl(0.06, 0.2, -0.08, L / 2 + 0.05, 0.3, P["dark"], verts=16, bevel=0.01)                 # winch drum
axle_cyl(0.065, 0.02, -0.19, L / 2 + 0.05, 0.3, P["steel"], verts=16)
axle_cyl(0.065, 0.02, 0.03, L / 2 + 0.05, 0.3, P["steel"], verts=16)
lpkit.box(0.08, 0.06, 0.07, 0.1, L / 2 + 0.04, 0.26, amber, bevel=0.01)                         # its motor

# Seats: two, canvas, the right one torn down to its frame.
lpkit.box(0.22, 0.24, 0.08, -0.15, 0.05, ZC + 0.02, canvas, bevel=0.02)
lpkit.box(0.22, 0.06, 0.28, -0.15, -0.08, ZC + 0.02, canvas, bevel=0.02)
lpkit.box(0.22, 0.24, 0.05, 0.15, 0.05, ZC + 0.02, olive, bevel=0.015)
lpkit.rod((0.05, -0.08, ZC + 0.05), (0.05, -0.08, ZC + 0.3), 0.012, tube); lpkit.rod((0.25, -0.08, ZC + 0.05), (0.25, -0.08, ZC + 0.3), 0.012, tube)
lpkit.rod((0.05, -0.08, ZC + 0.3), (0.25, -0.08, ZC + 0.3), 0.012, tube)

# Left flank: a long amber door with a rust patch and bolts, a fuel drum strapped behind it.
lpkit.box(0.04, 0.74, 0.22, -0.43, 0.06, ZC - 0.02, amber, bevel=0.01)
lpkit.box(0.045, 0.22, 0.12, -0.44, 0.2, ZC + 0.04, rust, rot=0.1, bevel=0.006)
for y in (-0.26, -0.06, 0.14, 0.38):
    lpkit.cyl(0.011, 0.02, -0.46, y, ZC + 0.16, bright, verts=6, rot=(0, math.pi / 2, 0))
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.1, depth=0.3, location=(-0.4, -0.3, ZC + 0.14), rotation=(math.pi / 2, 0, 0))
obj().data.materials.append(olive)
for y in (-0.22, -0.38):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.102, minor_radius=0.008, location=(-0.4, y, ZC + 0.14), rotation=(math.pi / 2, 0, 0))
    obj().data.materials.append(P["dark"])
# Right flank: a short corrugated sheet, cut ragged and hung askew, and a crate lashed on.
for k in range(7):
    lpkit.cyl(0.018, 0.4, 0.43, -0.05 + k * 0.05 - 0.15, ZC + 0.08 + (k % 2) * 0.004, P["steel"], verts=8, rot=(math.pi / 2, 0.06, 0))
lpkit.box(0.03, 0.42, 0.04, 0.43, 0.0, ZC - 0.02, rust, bevel=0.005)
lpkit.box(0.14, 0.16, 0.12, 0.38, 0.32, ZC + 0.02, P["dark"], rot=0.25, bevel=0.01)
lpkit.rod((0.3, 0.26, ZC + 0.14), (0.46, 0.38, ZC + 0.14), 0.008, canvas, verts=6)

# The roll cage: two hoops over the seats and a spine, braced to the rear; one brace bent (the left). Its hoops, spine and
# forward struts painted Grubstake's amber, worn to the steel at the edges, the bracing bare (all one grey, the frame read
# as a tangle at game scale with no mass for the eye to land on, and the faction's colour was at the corners alone).
cage = lpkit.worn("cage", (0.52, 0.31, 0.08), metal=0.35, rough=0.5, seams=3, rivets=False, wear=0.85, streaks=0.6)
HZ = ZC + 0.62
for y in (0.3, -0.18):
    lpkit.rod((-0.36, y, ZC), (-0.3, y, HZ), 0.038, cage)
    lpkit.rod((0.36, y, ZC), (0.3, y, HZ), 0.038, cage)
    lpkit.rod((-0.3, y, HZ), (0.3, y, HZ), 0.038, cage)
for sx in (-0.3, 0.3):
    lpkit.rod((sx, 0.3, HZ), (sx, -0.18, HZ), 0.038, cage)
lpkit.rod((0.3, -0.18, HZ), (0.28, -0.8, ZC + 0.33), 0.03, tube)
lpkit.rod((-0.3, -0.18, HZ), (-0.31, -0.4, HZ - 0.22), 0.03, tube)
lpkit.rod((-0.31, -0.4, HZ - 0.22), (-0.28, -0.8, ZC + 0.33), 0.03, tube)
lpkit.rod((-0.3, 0.3, HZ), (0.3, -0.18, HZ), 0.022, tube)                                       # a diagonal
# The cage's forward struts (the user, 2026-11-08: "Maybe we are just missing the forward part of the roll cage? the two
# angled struts?"): from the front hoop's top corners down to the frame by the hood, with a gusset at each foot.
for sx in (-1, 1):
    lpkit.rod((sx * 0.3, 0.3, HZ), (sx * 0.36, L / 2 - 0.22, ZC + 0.04), 0.038, cage)
    lpkit.rod((sx * 0.34, L / 2 - 0.4, ZC + 0.16), (sx * 0.36, L / 2 - 0.5, ZC + 0.02), 0.022, tube)
# A canvas sunshade over the front half of the cage, sagging.
lpkit.box(0.56, 0.3, 0.02, -0.02, 0.15, HZ + 0.02, canvas, rot=0.05, bevel=0.01)

# The turret ring (the user, 2026-11-08: "Yes to turret ring of course"): a plate across the rear hoop and the spine, a
# ring on it that every weapon module sits on (MODULES below), its centre RING.
# It belongs to the modules that sit on it (ring() below): on the shared chassis the flak buggy, its turret on the deck,
# showed it empty on its cage.
RING = (0, -0.12, HZ + 0.05)
def ring():
    lpkit.box(0.6, 0.2, 0.025, 0, -0.12, HZ + 0.02, P["dark"], bevel=0.008)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.02, location=RING, major_segments=32, minor_segments=8)
    obj().data.materials.append(P["steel"])
    for k in range(8):
        a = k * math.pi / 4
        lpkit.cyl(0.01, 0.015, math.cos(a) * 0.13, -0.12 + math.sin(a) * 0.13, HZ + 0.06, bright, verts=6)

# The back, open as the front is (the user, 2026-11-08: "Something is wrong with the back of the car": a lone box low
# between the wheels, the cage's braces landing on nothing, a stake of a stack): a tube frame round the engine bay, the
# braces landing on it, a bumper hoop at the tail with two tail lamps; the engine hung in it with its headers curling into
# a muffler, the stack bent up from that, an air filter; the radiator up behind the seats, as desert buggies carry it.
YR, YE = -0.42, -1.2                                     # where the bay leaves the cab, the tail
for sx in (-1, 1):
    lpkit.rod((sx * 0.24, YR, ZC), (sx * 0.24, YE, 0.26), 0.03, tube)                              # lower rails
    lpkit.rod((sx * 0.3, YR, ZC + 0.3), (sx * 0.26, YE, 0.5), 0.028, tube)                          # upper rails
    lpkit.rod((sx * 0.24, YE, 0.26), (sx * 0.26, YE, 0.5), 0.028, tube)                             # the tail hoop's legs
    lpkit.rod((sx * 0.24, -0.8, ZC - 0.02), (sx * 0.28, -0.8, ZC + 0.33), 0.024, tube)              # uprights at the axle
    lpkit.rod((sx * 0.24, YR, ZC), (sx * 0.28, -0.8, ZC + 0.33), 0.018, tube)                       # diagonals
    lpkit.box(0.05, 0.03, 0.04, sx * 0.24, YE - 0.02, 0.44, P["dark"], bevel=0.006)                # tail lamps
    lpkit.box(0.04, 0.01, 0.03, sx * 0.24, YE - 0.04, 0.445, tail, bevel=0.003)
for y, z in ((YE, 0.5), (-0.8, ZC + 0.33)):
    lpkit.rod((-0.28, y, z), (0.28, y, z), 0.026, tube)
lpkit.rod((-0.34, YE - 0.06, 0.24), (0.34, YE - 0.06, 0.24), 0.032, tube)                           # bumper
for sx in (-0.24, 0.24):
    lpkit.rod((sx, YE, 0.26), (sx, YE - 0.06, 0.24), 0.026, tube)
lpkit.rod((-0.28, -0.8, ZC + 0.33), (0.26, YE, 0.5), 0.016, tube)                                   # a diagonal
# The engine, hung on two cross tubes: a finned block, its head and plugs, an air filter, a belt on two pulleys.
YB = -0.98
for y in (YB + 0.14, YB - 0.14):
    lpkit.rod((-0.24, y, 0.25), (0.24, y, 0.25), 0.02, tube)
lpkit.box(0.34, 0.3, 0.22, 0, YB, 0.26, P["dark"], bevel=0.02)
for k in range(5):
    lpkit.box(0.38, 0.018, 0.16, 0, YB + 0.11 - k * 0.055, 0.29, P["steel"], bevel=0.004)
lpkit.box(0.28, 0.24, 0.07, 0, YB, 0.48, P["steel"], bevel=0.015)
for x in (-0.09, 0.0, 0.09):
    lpkit.cyl(0.018, 0.04, x, YB, 0.55, bright, verts=8)
lpkit.cyl(0.075, 0.1, -0.1, YB + 0.18, 0.46, P["dark"], verts=20, bevel=0.01)                    # air filter
lpkit.cyl(0.08, 0.015, -0.1, YB + 0.18, 0.56, P["steel"], verts=20)
axle_cyl(0.055, 0.03, 0.2, YB + 0.1, 0.4, bright, verts=16)
axle_cyl(0.03, 0.03, 0.2, YB - 0.08, 0.33, bright, verts=12)
lpkit.rod((0.21, YB + 0.1, 0.455), (0.21, YB - 0.08, 0.36), 0.009, P["dark"], verts=6)
lpkit.rod((0.21, YB + 0.1, 0.345), (0.21, YB - 0.08, 0.3), 0.009, P["dark"], verts=6)
# Headers: three pipes out of the block's right side, curling down into a muffler along it; the stack up from the muffler's
# front end beside the cage's rear brace. (Off the tail, behind the bumper, it read from above as a pipe out the back.)
for k in range(3):
    y = YB + 0.08 - k * 0.08
    lpkit.rod((0.17, y, 0.4), (0.25, y, 0.37), 0.016, rust, verts=8)
    lpkit.rod((0.25, y, 0.37), (0.3, YB - 0.1, 0.3), 0.016, rust, verts=8)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.05, depth=0.3, location=(0.31, YB + 0.02, 0.3), rotation=(math.pi / 2, 0, 0))
obj().data.materials.append(P["dark"])
# (Out on a bracket beside the frame since the flak's turret took the deck over the bay.)
for p0, p1 in (((0.31, YB + 0.17, 0.3), (0.38, YB + 0.24, 0.38)), ((0.38, YB + 0.24, 0.38), (0.4, YB + 0.26, 0.92)),
               ((0.4, YB + 0.26, 0.92), (0.4, YB + 0.2, 0.98))):
    lpkit.rod(p0, p1, 0.026, rust, verts=12)
lpkit.rod((0.28, YB + 0.26, 0.62), (0.4, YB + 0.26, 0.62), 0.012, tube)                             # its bracket
lpkit.box(0.07, 0.07, 0.01, 0.4, YB + 0.18, 0.99, P["dark"], rot=0.0, bevel=0.003)                 # rain cap
# The radiator up behind the seats, tilted back, its hoses down to the engine.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.04, -0.32, ZC + 0.48), rotation=(math.radians(-25), 0, 0))
o = obj(); o.scale = (0.34, 0.05, 0.3); o.data.materials.append(P["steel"])
for k in range(6):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.04 - 0.14 + k * 0.056, -0.345, ZC + 0.48), rotation=(math.radians(-25), 0, 0))
    o = obj(); o.scale = (0.012, 0.02, 0.27); o.data.materials.append(P["dark"])
lpkit.rod((-0.08, -0.36, ZC + 0.34), (-0.06, YB + 0.15, 0.46), 0.018, P["rubber"], verts=8)
lpkit.rod((0.16, -0.36, ZC + 0.62), (0.08, YB + 0.15, 0.5), 0.018, P["rubber"], verts=8)

# Kit: the spare wheel behind the left seat, a shovel and rope on the right of the cage, a searchlight on the front
# hoop's right corner, the lamp bar of three on the front hoop. (The radio whip is its own layer: ANTENNA below.)
axle_cyl(0.19, 0.16, -0.3, -0.38, ZC + 0.2, tyre, verts=24, bevel=0.04)
axle_cyl(0.1, 0.165, -0.3, -0.38, ZC + 0.2, P["dark"], verts=16)
lpkit.rod((0.35, -0.3, ZC + 0.1), (0.36, 0.25, ZC + 0.42), 0.012, P["dark"], verts=6)
lpkit.box(0.02, 0.1, 0.12, 0.36, 0.28, ZC + 0.4, P["steel"], rot=0.0, bevel=0.005)
bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.022, location=(0.38, -0.1, ZC + 0.36), rotation=(0, math.pi / 2, 0))
obj().data.materials.append(canvas)
lpkit.cyl(0.05, 0.08, 0.3, 0.3, HZ + 0.02, P["dark"], verts=16, bevel=0.01)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.06, depth=0.1, location=(0.3, 0.36, HZ + 0.1), rotation=(math.pi / 2, 0, 0))
obj().data.materials.append(P["steel"])
lpkit.cyl(0.045, 0.01, 0.3, 0.41, HZ + 0.1 - 0.005, lamp, verts=16, rot=(math.pi / 2, 0, 0))
lpkit.rod((-0.24, 0.3, HZ + 0.04), (0.18, 0.3, HZ + 0.04), 0.025, tube)
for sx in (-0.18, -0.04, 0.1):
    lpkit.box(0.08, 0.05, 0.06, sx, 0.33, HZ + 0.02, P["steel"], bevel=0.01)
    lpkit.cyl(0.026, 0.01, sx, 0.36, HZ + 0.05, lamp, verts=12, rot=(math.pi / 2, 0, 0))
for k in range(2):                                                                              # jerrycans, rear right
    lpkit.box(0.08, 0.16, 0.2, 0.36 - k * 0.1, -0.5, ZC, P["hazard"] if k else rust, bevel=0.015)

chassis = [o for o in scene.objects if o not in before]
# Weapon modules on the ring. Each builds round RING, nose forward (+y); the unit turns to aim (a unit has one picture a
# direction: no head turns on its own), so a module is fixed to the hull.
RX, RY, RZ = RING
def mg():
    """The buggy's: a machine gun on a pintle behind an amber shield, a cooling jacket, its ammo box and belt."""
    lpkit.cyl(0.1, 0.04, RX, RY, RZ, P["steel"], verts=20, bevel=0.008)
    lpkit.rod((RX, RY, RZ + 0.04), (RX, RY + 0.02, RZ + 0.16), 0.035, P["steel"])
    lpkit.box(0.13, 0.4, 0.1, RX, RY - 0.02, RZ + 0.13, P["dark"], bevel=0.015)
    lpkit.box(0.09, 0.12, 0.04, RX, RY - 0.16, RZ + 0.23, P["dark"], bevel=0.01)
    lpkit.rod((RX, RY + 0.16, RZ + 0.19), (RX, RY + 0.74, RZ + 0.19), 0.032, P["dark"], verts=12)
    lpkit.rod((RX, RY + 0.62, RZ + 0.19), (RX, RY + 0.78, RZ + 0.19), 0.042, P["steel"], verts=12)
    for y in (0.24, 0.32, 0.4, 0.48):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.036, minor_radius=0.008, location=(RX, RY + y, RZ + 0.19), rotation=(math.pi / 2, 0, 0))
        obj().data.materials.append(P["steel"])
    lpkit.box(0.36, 0.03, 0.2, RX, RY + 0.18, RZ + 0.11, amber, bevel=0.01)
    bolts(RX, RY + 0.18, RZ + 0.31, 0.3, 0.02, n=3)
    lpkit.box(0.11, 0.1, 0.1, RX + 0.13, RY - 0.06, RZ + 0.1, P["hazard"], bevel=0.01)
    lpkit.rod((RX + 0.1, RY - 0.02, RZ + 0.18), (RX + 0.03, RY + 0.05, RZ + 0.19), 0.015, bright, verts=6)
def slug():
    """The slug buggy's: one long heavy barrel with a muzzle brake, a breech block, recoil cylinders, a wide shield."""
    lpkit.cyl(0.12, 0.05, RX, RY, RZ, P["steel"], verts=20, bevel=0.008)
    lpkit.box(0.2, 0.34, 0.16, RX, RY - 0.04, RZ + 0.05, P["dark"], bevel=0.02)
    lpkit.box(0.16, 0.12, 0.1, RX, RY - 0.24, RZ + 0.08, P["steel"], bevel=0.015)
    lpkit.rod((RX, RY + 0.1, RZ + 0.15), (RX, RY + 1.02, RZ + 0.15), 0.045, P["dark"], verts=16)
    lpkit.rod((RX, RY + 0.96, RZ + 0.15), (RX, RY + 1.1, RZ + 0.15), 0.06, P["steel"], verts=16)
    for sx in (-1, 1):
        lpkit.rod((RX + sx * 0.06, RY - 0.05, RZ + 0.1), (RX + sx * 0.06, RY + 0.38, RZ + 0.1), 0.022, bright, verts=10)
        lpkit.box(0.03, 0.06, 0.03, RX + sx * 0.03, RY + 1.03, RZ + 0.15, P["dark"], bevel=0.004)
    lpkit.box(0.46, 0.035, 0.24, RX, RY + 0.16, RZ + 0.04, rust, bevel=0.01)
    bolts(RX, RY + 0.16, RZ + 0.28, 0.4, 0.03, n=4)
    lpkit.box(0.14, 0.16, 0.12, RX - 0.18, RY - 0.12, RZ + 0.03, P["hazard"], bevel=0.01)
def flak():
    """The flak buggy's: a Wirbelwind (the user, 2026-11-08: "Flak turret could maybe be much larger? To communicate the
    difference in silhouette. Think wirbelwind"): a nine-sided open-topped turret of plates, far wider than the other
    guns' shields, its rim sky blue (anti-air's colour), four barrels raised in a two by two mount inside. Seated on the
    deck over the engine bay, not the cage's ring (the user: "a little too raised? (considering the perspective of
    factorio)": a tile up, it floated over the buggy on screen; a Wirbelwind's turret sits on its hull)."""
    RX, RY, RZ = 0.0, -0.82, ZC + 0.34
    TR, TH, NS = 0.32, 0.18, 9
    lpkit.cyl(TR * 0.9, 0.04, RX, RY, RZ, P["dark"], verts=NS * 4, bevel=0.008)                   # turret floor
    for k in range(NS):                                                                            # its plates, leaning out
        a0, a1 = 2 * math.pi * k / NS, 2 * math.pi * (k + 1) / NS
        am = (a0 + a1) / 2
        w = 2 * TR * math.sin(math.pi / NS) + 0.01
        bpy.ops.mesh.primitive_cube_add(size=1, location=(RX + math.cos(am) * TR, RY + math.sin(am) * TR, RZ + 0.04 + TH / 2),
                                        rotation=(0, math.radians(-8), am))
        o = obj(); o.scale = (0.022, w, TH); o.data.materials.append(rust if k % 3 == 1 else P["steel"])
        md = o.modifiers.new("b", "BEVEL"); md.width = 0.004; md.segments = 1
        bpy.ops.mesh.primitive_cube_add(size=1, location=(RX + math.cos(am) * (TR + 0.016), RY + math.sin(am) * (TR + 0.016),
                                        RZ + 0.04 + TH - 0.015), rotation=(0, math.radians(-8), am))
        o = obj(); o.scale = (0.03, w, 0.03); o.data.materials.append(sky)
        bolts(RX + math.cos(am) * (TR + 0.02), RY + math.sin(am) * (TR + 0.02), RZ + 0.04 + TH * 0.4, 0.02, 0.02, n=2)
    # The mount: a cradle on a pedestal, four barrels raised, their breeches and two magazines a side.
    lpkit.cyl(0.06, 0.12, RX, RY, RZ + 0.04, P["dark"], verts=16)
    lpkit.box(0.26, 0.2, 0.14, RX, RY - 0.02, RZ + 0.14, P["dark"], bevel=0.015)
    a = math.radians(55)
    for sx in (-0.055, 0.055):
        for sz in (0.0, 0.07):
            p0 = (RX + sx, RY + 0.06, RZ + 0.24 + sz)
            p1 = (RX + sx, RY + 0.06 + math.cos(a) * 0.58, RZ + 0.24 + sz + math.sin(a) * 0.58)
            lpkit.rod(p0, p1, 0.017, P["dark"], verts=10)
            lpkit.rod((p1[0], p1[1] - math.cos(a) * 0.08, p1[2] - math.sin(a) * 0.08), p1, 0.024, P["steel"], verts=10)
    for sx in (-1, 1):
        lpkit.box(0.05, 0.12, 0.16, RX + sx * 0.16, RY - 0.04, RZ + 0.18, sky, bevel=0.008)
    # A ring sight on a stalk.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.007, location=(RX + 0.2, RY + 0.12, RZ + 0.46),
                                     rotation=(math.pi / 2 - a, 0, 0))
    obj().data.materials.append(bright)
    lpkit.rod((RX + 0.2, RY + 0.06, RZ + 0.2), (RX + 0.2, RY + 0.12, RZ + 0.46), 0.008, P["steel"], verts=6)
# Each weapon's kit on the chassis (the user, 2026-11-08: "A buggy could also vary its chassis depending on the weapon (ammo
# tanks, etc)"): in the module's own layer, so the chassis render stays one. On a deck over the rear axle.
DECK = (-0.7, ZC + 0.36)
def deck():
    y, z = DECK
    lpkit.box(0.56, 0.24, 0.02, 0, y, z, P["dark"], bevel=0.005)
    for k in range(5):
        lpkit.box(0.56, 0.012, 0.012, 0, y - 0.1 + k * 0.05, z + 0.02, P["steel"], bevel=0.0)
def mg_kit():
    """Ammo cans stacked on the deck, strapped, a belt up to the gun."""
    deck(); y, z = DECK
    for k, (x, dz) in enumerate(((-0.14, 0), (0.0, 0), (-0.07, 0.11))):
        lpkit.box(0.12, 0.2, 0.11, x, y, z + 0.02 + dz, olive, bevel=0.01)
        lpkit.box(0.09, 0.04, 0.012, x, y + 0.06, z + 0.13 + dz, P["dark"], bevel=0.003)
    lpkit.rod((-0.2, y, z + 0.18), (0.06, y, z + 0.18), 0.008, canvas, verts=6)
    for k in range(8):                                                     # the belt, links up to the gun's box
        f = k / 7
        lpkit.box(0.03, 0.02, 0.015, -0.07 + 0.2 * f, y + (RY - 0.06 - y) * f, z + 0.24 + (RZ + 0.1 - z - 0.24) * f,
                  copper, bevel=0.0)
def slug_kit():
    """A big red ammo crate across the rear deck, yellow bands and latches, a feed chute up to the gun (the user,
    2026-11-08: "a big red ammo box in the back with yellow accents, to remind the player of actual slugs"; a brass shell
    rack before), and a ram plate bolted on the bull bar for the heavier front."""
    deck(); y, z = DECK
    # A real ammo box, not a block (the first, a bare red cube, read as a toy): rounded edges, ribs pressed along its
    # sides, a lid with a rim and two clamp latches, carry handles at its ends, its bands yellow, a feed chute to the gun.
    CW, CD, CH = 0.44, 0.28, 0.22
    lpkit.box(CW, CD, CH, 0, y - 0.02, z + 0.02, red, bevel=0.03)
    for k in range(3):
        for sd in (-1, 1):
            lpkit.box(CW - 0.08, 0.012, 0.018, 0, y - 0.02 + sd * (CD / 2 + 0.002), z + 0.07 + k * 0.05, red, bevel=0.006)
    lpkit.box(CW + 0.02, CD + 0.02, 0.035, 0, y - 0.02, z + 0.02 + CH, red, bevel=0.012)
    for x in (-0.15, 0.15):
        lpkit.box(0.04, CD + 0.024, CH + 0.05, x, y - 0.02, z + 0.02, yellow, bevel=0.008)              # over the lid
    for x in (-0.07, 0.07):
        lpkit.box(0.04, 0.025, 0.07, x, y - 0.02 + CD / 2 + 0.012, z + CH - 0.03, P["steel"], bevel=0.006)
        lpkit.rod((x - 0.015, y - 0.02 + CD / 2 + 0.03, z + CH - 0.0), (x + 0.015, y - 0.02 + CD / 2 + 0.03, z + CH - 0.0), 0.006, bright)
    for sd in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.035, minor_radius=0.007, location=(sd * (CW / 2 + 0.012), y - 0.02, z + CH - 0.02),
                                         rotation=(0, math.pi / 2, 0), major_segments=24, minor_segments=8)
        obj().data.materials.append(P["steel"])
    lpkit.box(0.14, 0.006, 0.06, 0.0, y - 0.02 - CD / 2 - 0.004, z + 0.1, yellow, bevel=0.002)          # a stencil plate
    for k in range(6):                                                                              # the chute up to the gun
        f = k / 5
        lpkit.box(0.06, 0.05, 0.03, 0.04, y + 0.1 + (RY - 0.2 - y - 0.1) * f, z + 0.28 + (RZ + 0.06 - z - 0.28) * f,
                  P["dark"], bevel=0.008)
    lpkit.box(0.66, 0.03, 0.2, 0, L / 2 + 0.01, 0.2, rust, bevel=0.01)
    bolts(0, L / 2 + 0.01, 0.4, 0.6, 0.02, n=4)
def flak_kit():
    """A ranging radar on a mast at the tail: anti-air read from afar. (Its drums on the deck went when the turret took
    the deck.)"""
    for sx in ():
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.1, depth=0.22, location=(sx, y, z + 0.12), rotation=(math.pi / 2, 0, 0))
        obj().data.materials.append(sky)
        for dy in (-0.07, 0.07):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.102, minor_radius=0.008, location=(sx, y + dy, z + 0.12), rotation=(math.pi / 2, 0, 0))
            obj().data.materials.append(P["dark"])
    mx, my = -0.22, -1.2
    lpkit.rod((mx, my, 0.5), (mx, my, 1.15), 0.02, P["steel"], verts=8)
    lpkit.rod((mx - 0.06, my, 0.5), (mx, my, 0.8), 0.012, P["steel"], verts=6)
    lpkit.cyl(0.03, 0.04, mx, my, 1.15, P["dark"], verts=12)
    lpkit.box(0.36, 0.025, 0.1, mx, my, 1.19, P["dark"], rot=0.6, bevel=0.006)
    lpkit.box(0.34, 0.01, 0.08, mx, my, 1.2, P["steel"], rot=0.6, bevel=0.0)
# The flak's accent: sky blue, anti-air's colour since 2026-10-23 (units.lua; olive was lost on grass).
red = lpkit.worn("red", (0.36, 0.07, 0.04), metal=0.25, rough=0.6, seams=1.2, rivets=False, wear=0.8)   # (0.55 read as a toy; seams 5 drew bricks on the crate)
yellow = lpkit.worn("yellow", (0.52, 0.38, 0.06), metal=0.2, rough=0.65, seams=1.2, rivets=False, wear=0.7)
sky = lpkit.worn("sky", (0.25, 0.35, 0.45), metal=0.3, rough=0.6, seams=5, rivets=False, wear=0.8)
copper = lpkit.mat("brass", (0.6, 0.42, 0.15), metal=0.8, rough=0.35, grime=0.4)
MODULES = {"mg": lambda: (ring(), mg(), mg_kit()), "slug": lambda: (ring(), slug(), slug_kit()), "flak": lambda: (flak(), flak_kit())}
which = os.environ.get("LP_MODULES", ",".join(MODULES)).split(",")
modules = {}
for name in which:
    b4 = set(scene.objects); MODULES[name](); modules[name] = [o for o in scene.objects if o not in b4]
# Grime on everything but the lamps (lpkit.dirty): the scrap raider dirtier than vanilla's car, not cleaner. After the
# modules, so their materials have it too (made after it, the red crate and sky blue had none and read as toys).
GRIME = float(os.environ.get("LP_GRIME", 1.0))
for m in bpy.data.materials:
    if m.name not in GLOWS and m.use_nodes:
        # (At scale 4 a patch was as big as a part: whole tubes darkened evenly, the first grime render. Finer.)
        # (Dust at 0.7 coated it all one beige, the amber and the tyres too, the second: smudges dark, dust light, none on
        # rubber.)
        rubberish = m.name in ("tyre", "dust", "rubber")
        lpkit.dirty(m, dirt=(0.4 if rubberish else 0.8) * GRIME, dust=(0.0 if rubberish else 0.3) * GRIME,
                    rust=(0.0 if rubberish else 0.6) * GRIME, dirt_rgb=(0.035, 0.03, 0.02),
                    scale=float(os.environ.get("LP_GRIME_SCALE", 13)))
# Smooth shading, edges sharper than 35 degrees kept sharp.
for o in scene.objects:
    if o.type == "MESH":
        o.data.shade_smooth(); o.data.set_sharp_from_angle(angle=math.radians(35))
# LP_WRECK=1: the buggies' wreck (one for the three: the chassis, its gun gone; 4 directions, its shadow in the
# picture), through the vehicle kit's wreck pass (this script predates the kit), then stop.
if os.environ.get("LP_WRECK"):
    import vehicle
    vehicle.scene = scene
    for objs in modules.values():
        for o in objs: o.hide_render = True
    vehicle.wreck(chassis, out, seed=5, tilt=(6, -5), sink=0.05, tiles=2, margin=1.2, scorch=1.4)
    print("buggy wreck to", out); sys.exit(0)
model = chassis + [o for objs in modules.values() for o in objs]
pivot = bpy.data.objects.new("pivot", None); scene.collection.objects.link(pivot)
wheel_objs = {id(o) for objs, _ in WHEELS for o in objs}
for o in model:
    if id(o) not in wheel_objs:
        o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
# Each wheel on a hub of its own at its axle (turned for the rolling layer), the hubs on the pivot.
hubs = []
for objs, (hx, hy, hz) in WHEELS:
    hub = bpy.data.objects.new("hub", None); scene.collection.objects.link(hub); hub.location = (hx, hy, hz)
    bpy.context.view_layer.update()
    for o in objs:
        o.parent = hub; o.matrix_parent_inverse = hub.matrix_world.inverted()
    hub.parent = pivot; hub.matrix_parent_inverse = pivot.matrix_world.inverted()
    hubs.append(hub)

ground, sun, world = lpkit.stage(scene, 2, 1.2)
# Light: the stage's sky fill read flat and pale beside vanilla's car at game scale (the first look, 2026-11-08: the user,
# "a little bright or faded"; measured, half its contrast), so little sky, more sun, and the High Contrast look.
sun.data.energy = float(os.environ.get("LP_SUN", 5.5))
scene.view_settings.look = os.environ.get("LP_LOOK", "High Contrast")
FILL = float(os.environ.get("LP_FILL", 0.04))
# LP_CLOSE=1: one close still of the front right wheel (to judge what is modelled where a sprite loses it), then stop.
if os.environ.get("LP_CLOSE"):
    # LP_CLOSE=front: the nose from its front right, 1.4 tiles across.
    # LP_CLOSE=rear: the tail from its rear left, 1.8 tiles across.
    kind = os.environ["LP_CLOSE"]
    turn, at, span = {"front": (150, (0, AX, 0.3), 1.4), "rear": (-30, (0, -AX - 0.1, 0.4), 1.8)}.get(
        kind, (-60, (AXLES[1][1] / 2, AXLES[1][0], AXLES[1][2]), 1.0))
    pivot.rotation_euler = (0, 0, math.radians(turn))
    bpy.context.view_layer.update()
    target = pivot.matrix_world @ mathutils.Vector(at)
    cam = scene.camera; cam.location = target + mathutils.Vector((0, -20, 20)); cam.data.ortho_scale = span
    scene.render.resolution_x = scene.render.resolution_y = 700
    for name, objs in modules.items():
        for o in objs: o.hide_render = name != os.environ.get("LP_CLOSE_MOD")
    ground.hide_render = True; sun.hide_render = False; world.node_tree.nodes["Background"].inputs[1].default_value = FILL
    lpkit.render(scene, f"{out}/close.png"); sys.exit(0)
bg = world.node_tree.nodes["Background"]

# Passes, each direction: the chassis alone (body, glow); each module with the chassis as a holdout (so the cage hides
# it where it passes behind, and stacked on the chassis layer it covers what it stands in front of), and the shadow of
# chassis and module together. out/chassis/{body,glow}, out/<module>/{body,glow,shadow}: one sheet.py run each.
def show(objs, on):
    for o in objs: o.hide_render = not on
def lit(on):
    sun.hide_render = not on; bg.inputs[1].default_value = FILL if on else 0.0
for k in ["chassis/body", "chassis/glow"] + [f"{n}/{p}" for n in modules for p in ("body", "glow", "shadow")]:
    if os.environ.get("LP_ONLY") != "antenna": os.makedirs(f"{out}/{k}", exist_ok=True)
# LP_ONLY=wheels: the wheels rolling, their own layer of ROLL frames a direction, one turn over the cycle (forward, the
# top of a wheel going ahead), the rest of the chassis a holdout; and the chassis again without them (the user,
# 2026-11-08, on animation: "Do wheels turn when turning?": no unit steers, but its wheels can roll). A run animation
# steps with the distance covered: they roll driving, stand parked. out/wheels/body holds direction * ROLL + frame.
ROLL = 4
if os.environ.get("LP_ONLY") == "wheels":
    rest = [o for o in chassis if id(o) not in wheel_objs]
    wobjs = [o for objs, _ in WHEELS for o in objs]
    for k in ("chassis/body", "chassis/glow", "wheels/body"): os.makedirs(f"{out}/{k}", exist_ok=True)
    for objs in modules.values(): show(objs, False)
    for d in range(N):
        pivot.rotation_euler = (0, 0, -2 * math.pi * d / N)
        ground.hide_render = True
        for h in hubs: h.rotation_euler = (0, 0, 0)
        show(wobjs, False)
        for o in rest: o.is_holdout = False
        lit(True); lpkit.render(scene, f"{out}/chassis/body/{d:03d}.png")
        for o in rest: o.is_holdout = not any(s.material and s.material.name in GLOWS for s in o.material_slots)
        lit(False); lpkit.render(scene, f"{out}/chassis/glow/{d:03d}.png")
        show(wobjs, True)
        for o in rest: o.is_holdout = True
        for o in wobjs: o.is_holdout = False
        for f in range(ROLL):
            for h in hubs: h.rotation_euler = (-2 * math.pi * f / ROLL, 0, 0)
            lit(True); lpkit.render(scene, f"{out}/wheels/body/{d * ROLL + f:04d}.png")
    print("buggy wheels:", N, "directions,", ROLL, "frames, to", out); sys.exit(0)
# LP_ONLY=antenna: the antenna layer alone (the rest rendered before).
for d in range(0 if os.environ.get("LP_ONLY") == "antenna" else N):
    pivot.rotation_euler = (0, 0, -2 * math.pi * d / N)          # north first, clockwise seen from above
    ground.hide_render = True
    for objs in modules.values(): show(objs, False)
    if os.environ.get("LP_SKIP") != "chassis":                    # LP_SKIP=chassis: a module again, the chassis kept
        for o in chassis: o.is_holdout = False
        lit(True); lpkit.render(scene, f"{out}/chassis/body/{d:03d}.png")
        for o in chassis: o.is_holdout = not any(s.material and s.material.name in GLOWS for s in o.material_slots)
        lit(False); lpkit.render(scene, f"{out}/chassis/glow/{d:03d}.png")
    for name, objs in modules.items():
        show(objs, True)
        for o in chassis: o.is_holdout = True
        lit(True); lpkit.render(scene, f"{out}/{name}/body/{d:03d}.png")
        for o in objs: o.is_holdout = True
        lit(False); lpkit.render(scene, f"{out}/{name}/glow/{d:03d}.png")
        for o in chassis + objs: o.is_holdout = False; o.visible_camera = False
        ground.hide_render = False; lit(True); lpkit.render(scene, f"{out}/{name}/shadow/{d:03d}.png")
        ground.hide_render = True
        for o in chassis + objs: o.visible_camera = True
        show(objs, False)
# The antenna (the user, 2026-11-08: "An antenna in the back? If yes possible to animate it while moving?"): a tall whip
# on the tail hoop's right corner with a pennant, its own layer of SWAY frames a direction (a unit's run animation steps
# with the distance it covers and holds still when it stops: the whip sways driving, stands parked). Bent back by the
# drag and swinging; the chassis a holdout. out/antenna/body holds direction * SWAY + frame. (A thin whip on the cage
# had been there all along and read as nothing at game scale.) LP_ANTENNA=0 skips it.
SWAY = 8
if os.environ.get("LP_ANTENNA", "1") != "0":
    base_pt = mathutils.Vector((0.26, -1.2, 0.5)); H = 1.05
    cu = bpy.data.curves.new("whip", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = 0.015; cu.bevel_resolution = 2
    sp = cu.splines.new("POLY"); NP = 10; sp.points.add(NP - 1)
    whip = bpy.data.objects.new("whip", cu); scene.collection.objects.link(whip); cu.materials.append(bright)  # (dark, it vanished over the body)
    flag = bpy.data.objects.new("pennant", bpy.data.meshes.new("pennant")); scene.collection.objects.link(flag)
    flag.data.materials.append(rag)
    tipcap = lpkit.cyl(0.02, 0.03, 0, 0, 0, P["steel"], verts=8)
    pivot.rotation_euler = (0, 0, 0); bpy.context.view_layer.update()     # parented unturned: points in the model's frame
    for o in (whip, flag, tipcap):
        o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
    def bend(f):
        """The whip's points for frame f: back by the drag, swinging back and forth and a little sideways."""
        ph = 2 * math.pi * f / SWAY
        # (0.2 back and 0.15 of swing trailed it far behind the tail, near detached in the mockup: halved.)
        back, side = 0.1 + 0.1 * math.sin(ph), 0.06 * math.cos(ph)
        pts = []
        for k in range(NP):
            t = k / (NP - 1)
            pts.append(base_pt + mathutils.Vector((side * t * t, -back * t * t, H * t - 0.25 * back * t * t)))
        return pts
    def pennant(pts):
        import bmesh
        a, b = pts[-3], pts[-1]
        d = (b - a).normalized(); away = mathutils.Vector((0.3, -1, 0)).normalized()
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in (a, b, b + away * 0.26 + d * -0.04, a + away * 0.2)]
        bm.faces.new(vs); bm.to_mesh(flag.data); bm.free()
    for k in ["antenna/body", "antenna/glow"]:
        os.makedirs(f"{out}/{k}", exist_ok=True)
    for objs in modules.values(): show(objs, False)
    for o in chassis: o.is_holdout = True
    for d in range(N):
        pivot.rotation_euler = (0, 0, -2 * math.pi * d / N)
        for f in range(SWAY):
            pts = bend(f)
            for k, q in enumerate(pts): sp.points[k].co = (q.x, q.y, q.z, 1)
            pennant(pts); tipcap.location = pts[-1] - mathutils.Vector((0, 0, 0.015))
            lit(True); ground.hide_render = True
            lpkit.render(scene, f"{out}/antenna/body/{d * SWAY + f:04d}.png")
    # An empty glow per frame (sheet.py wants one); the first, cleared.
    from shutil import copyfile
    blank = f"{out}/antenna/blank.png"
    for o in (whip, flag, tipcap): o.hide_render = True
    lpkit.render(scene, blank)
    for i in range(N * SWAY): copyfile(blank, f"{out}/antenna/glow/{i:04d}.png")
    os.remove(blank)
print("buggy:", N, "directions to", out)
