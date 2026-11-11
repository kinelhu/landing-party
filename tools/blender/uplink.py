"""The corporations' uplink (6x6: their link home; destroying it ends the landings), modelled and rendered in the style
of their other buildings (the user, 2026-11-04: Space Age's fusion reactor at scale "not looks matched", "We try
homemade? Bigger is not necessarily an issue"; of the first try, four houses round a core: "A little too symmetrical and
toy like"). An installation grown to fit its ground: the dish off-centre to the north-west on a heavy pedestal, a tall
control block to the east, a squat transformer yard with two tanks to the south-west, a cable tray and pipe runs between
them, a lattice mast on the control block, small kit everywhere. No slab: it stands on the ground. 32 frames as the radar's
directions, the dish turning (its shadow with it).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/uplink.py -- <out_dir> [serenity|grubstake]
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/<corp>/uplink
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
CORP = args[1] if len(args) > 1 else "serenity"
FRAMES, TILES, MARGIN = int(os.environ.get("LP_FRAMES", 32)), 6, 3.0
scene = lpkit.reset(); scene.cycles.samples = 64
# (The corporations' palette of their clay-first buildings: on the bright worn one it rated 2, "bit too toy like", the
# user, 2026-11-10.)
P = lpkit.palette_faction(CORP)
LIGHT = (0.25, 0.7, 1.0) if CORP == "serenity" else (1.0, 0.55, 0.12)
P["window"] = lpkit.mat("window", (0.05, 0.05, 0.04), emit=LIGHT, strength=0.9, grime=0.0)
rust = P["rust"]
B = lpkit.box
rnd = random.Random(7)

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

DX, DY = -0.8, 0.7          # the dish's pedestal: off-centre, north-west
rings = []
def kit(x, y, z, n=3):
    """Small boxes on a roof: conduit boxes, a hatch, a fan cowl (the density of vanilla's machines)."""
    for _ in range(n):
        w, d, h = rnd.uniform(0.12, 0.3), rnd.uniform(0.12, 0.3), rnd.uniform(0.06, 0.16)
        B(w, d, h, x + rnd.uniform(-0.35, 0.35), y + rnd.uniform(-0.3, 0.3), z, rnd.choice([P["dark"], P["steel"], rust]))

def fixed():
    # The dish's pedestal: a heavy stepped octagon.
    lpkit.cyl(1.25, 0.35, DX, DY, 0, P["dark"], verts=8, rot=(0, 0, math.pi / 8))
    lpkit.cyl(1.0, 1.0, DX, DY, 0.35, P["paint"], verts=8, rot=(0, 0, math.pi / 8))
    lpkit.cyl(1.04, 0.07, DX, DY, 1.33, P["steel"], verts=8, rot=(0, 0, math.pi / 8))
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        B(0.35, 0.04, 0.4, DX + math.cos(a) * 0.93, DY + math.sin(a) * 0.93, 0.6, P["dark"] if k % 3 else P["steel"], rot=a + math.pi / 2)
    B(0.5, 0.05, 0.08, DX, DY - 1.0, 0.2, P["hazard"])
    # The control block: tall, to the east, its long side north-south; windows lit, a stair, a roof deck with kit.
    cx, cy = 1.75, 0.35
    B(1.5, 2.6, 1.55, cx, cy, 0, P["paint"])
    B(1.56, 2.66, 0.07, cx, cy, 1.55, P["steel"])
    for k in range(3):
        B(0.32, 0.04, 0.18, cx - 0.35 + k * 0.35, cy - 1.32, 1.05, P["window"])
    B(0.6, 0.04, 0.55, cx + 0.3, cy - 1.32, 0.0, P["dark"])                          # its door
    B(0.5, 0.05, 0.06, cx + 0.3, cy - 1.33, 0.58, P["hazard"])
    for k in range(6):                                                               # a stair up its west side
        B(0.35, 0.18, 0.04, cx - 0.92, cy - 0.9 + k * 0.2, 0.15 + k * 0.22, P["steel"])
    kit(cx, cy - 0.5, 1.62, 4); kit(cx, cy + 0.7, 1.62, 3)
    B(0.6, 0.6, 0.35, cx + 0.3, cy + 0.85, 1.62, P["steel"])                         # an air handler
    lpkit.cyl(0.22, 0.04, cx + 0.3, cy + 0.85, 1.97, P["dark"], verts=16)
    # The transformer yard, south-west: a low block, two tanks, insulators.
    tx, ty = -1.45, -1.75
    B(1.9, 1.2, 0.55, tx, ty, 0, P["dark"])
    B(1.94, 1.24, 0.04, tx, ty, 0.55, P["steel"])
    for k, (ox, r) in enumerate(((-0.5, 0.28), (0.35, 0.22))):
        lpkit.cyl(r, 0.6, tx + ox, ty + 0.05, 0.59, P["paint"] if k == 0 else rust, verts=20)
        lpkit.cyl(r + 0.02, 0.04, tx + ox, ty + 0.05, 1.19, P["steel"], verts=20)
    for k in range(4):
        lpkit.cyl(0.04, 0.3, tx + 0.75, ty - 0.35 + k * 0.22, 0.59, P["steel"], verts=8)
    # A small hut to the south-east, a fuel drum or two.
    B(0.8, 0.7, 0.6, 1.1, -2.0, 0, P["paint"]); B(0.84, 0.74, 0.05, 1.1, -2.0, 0.6, P["steel"])
    B(0.25, 0.04, 0.12, 1.0, -2.36, 0.35, P["window"])
    for ox in (0.0, 0.3):
        lpkit.cyl(0.11, 0.3, 2.1 + ox, -2.35, 0, rust, verts=12)
    # Runs between them: a cable tray on posts from the yard to the pedestal and on to the control block; a pipe.
    for (x0, y0), (x1, y1) in (((-1.45, -1.15), (DX, DY - 1.0)), ((DX + 1.0, DY), (cx - 0.75, cy))):
        n = 3
        for k in range(n + 1):
            x, y = x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n
            lpkit.cyl(0.03, 0.55, x, y, 0, P["steel"], verts=6)
        lpkit.rod((x0, y0, 0.58), (x1, y1, 0.58), 0.05, P["dark"])
    lpkit.rod((-0.4, -1.9, 0.18), (0.7, -2.0, 0.18), 0.06, P["steel"])
    lpkit.rod((0.7, -2.0, 0.18), (1.0, -0.9, 0.18), 0.06, P["steel"])
    # The mast, on the control block's north end: a pulse climbing its rings.
    mx, my, mz = cx - 0.3, cy + 1.05, 1.62
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        lpkit.rod((mx + math.cos(a) * 0.26, my + math.sin(a) * 0.26, mz), (mx + math.cos(a) * 0.06, my + math.sin(a) * 0.06, mz + 2.6),
                  0.022, P["steel"])
    for z in (0.5, 1.1, 1.7, 2.2):
        lpkit.rod((mx - 0.2, my, mz + z), (mx + 0.2, my, mz + z), 0.013, P["steel"])
    for i, z in enumerate((1.4, 1.95, 2.45)):
        m = lpkit.mat(f"ring{i}", (0.06, 0.08, 0.09), metal=0.5, rough=0.4, emit=LIGHT, strength=0.0)
        rings.append(m)
        lpkit.torus(0.18 - i * 0.03, 0.03, mx, my, mz + z, m)
    lpkit.sphere(0.07, mx, my, mz + 2.7, P["glow"])
    lpkit.cyl(0.5, 0.2, DX, DY, 1.4, P["steel"], verts=32)                           # the bearing

def moving():
    lpkit.cyl(0.7, 0.12, DX, DY, 1.6, P["dark"], verts=32)                           # turntable
    for sx in (-0.5, 0.5):
        B(0.1, 0.35, 1.1, DX + sx, DY, 1.65, P["paint"])                            # yoke arms
    n = (0, -math.cos(math.radians(55)), math.sin(math.radians(55)))                  # towards the camera at rest
    axle = (DX, DY, 2.65)
    c = tuple(axle[i] + n[i] * 0.3 for i in range(3))
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=1.9, radius2=0.3, depth=0.6, end_fill_type="NOTHING",
                                    location=c, rotation=(math.radians(-145), 0, 0))
    d = bpy.context.object
    md = d.modifiers.new("s", "SOLIDIFY"); md.thickness = 0.05
    d.data.materials.append(P["paint"])
    bpy.ops.mesh.primitive_torus_add(major_radius=1.9, minor_radius=0.06, location=tuple(axle[i] + n[i] * 0.6 for i in range(3)),
                                     rotation=(math.radians(-145), 0, 0))
    bpy.context.object.data.materials.append(P["dark"])
    focus = tuple(axle[i] + n[i] * 1.8 for i in range(3))
    # Ribs on its back, hub to rim (a plain cone read as a toy's dish).
    for k in range(12):
        ang = k * math.pi / 6
        uu = tuple(math.cos(ang) * (1, 0, 0)[i] + math.sin(ang) * (0, n[2], -n[1])[i] for i in range(3))
        p0 = tuple(c[i] - n[i] * 0.3 + uu[i] * 0.3 for i in range(3)); p1 = tuple(c[i] + n[i] * 0.28 + uu[i] * 1.85 for i in range(3))
        lpkit.rod(p0, p1, 0.035, P["dark"])
    rc = tuple(axle[i] + n[i] * 0.55 for i in range(3))
    u, v = (1, 0, 0), (0, n[2], -n[1])
    for ang in (math.pi / 2, math.pi / 2 + 2.1, math.pi / 2 + 4.2):
        rim = tuple(rc[i] + 1.75 * (math.cos(ang) * u[i] + math.sin(ang) * v[i]) for i in range(3))
        lpkit.rod(rim, focus, 0.02, P["steel"])
    lpkit.sphere(0.12, *focus, P["glow"])
    B(0.5, 0.45, 0.4, DX, DY + 0.55, 2.05, P["dark"])                                # counterweight, behind
    lpkit.rod((DX - 0.5, DY, 2.65), (DX + 0.5, DY, 2.65), 0.06, P["steel"])

still_objs = group(fixed)
still_objs += lpkit.scatter(still_objs, {P["paint"], P["trim"]}, P["dark"], P["steel"], seed=9, density=3.0)
turn_objs = group(moving)
bpy.ops.object.empty_add(location=(DX, DY, 0)); pivot = bpy.context.object
for o in turn_objs:
    o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
def set_frame(f):
    t = f / FRAMES
    pivot.rotation_euler = (0, 0, -2 * math.pi * t)
    for i, m in enumerate(rings):
        dd = abs(((t * 3 - i) + 1.5) % 3 - 1.5)
        lpkit.emission(m, max(0.0, 1.8 - 1.7 * dd))
    lpkit.emission(P["glow"], 0.9 + 0.5 * math.sin(t * 4 * math.pi))
    bpy.context.view_layer.update()
model = still_objs + turn_objs
lpkit.bevel_all(model)
ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
lpkit.passes(scene, out, FRAMES, set_frame, model, set(rings) | {P["glow"], P["window"]}, ground, sun, world, shadow_each=True)
print("rendered uplink", CORP, out)
