"""Grubstake's crawler: a bulldozer's tracked chassis pressed into service (the unit pass, 2026-11-08: Grubstake first, the
Scorcher and the Dozer on one chassis as the buggies share theirs; the user: "The kill dozer is a genius pull", "Mad Max
as a general inspiration is good also"). The base: two track frames with their sprocket, idler, road wheels and return
rollers, a tub between them, the engine under a hood at the front, stacks, a fuel tank at the back. The tracks are an
animated layer, TRACK frames a direction (the shoes move one pitch over a cycle: a unit's run animation steps with the
distance it covers, so they run driving and stand parked). Modules: the Killdozer box and blade (dozer), the open
fighting cab and flamer (scorcher).

    /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/crawler.py -- <out_dir> [N=64]
    then one sheet.py run a part: out/base, out/anim, out/<module>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import vehicle as V
from vehicle import M, box, rod, cyl, axle_cyl, bolt, oriented

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
N = int(args[1]) if len(args) > 1 else 64
V.setup()

# Proportions in tiles, forward along +y: about vanilla's tank (1.8 by 2.6).
TX, TW = 0.74, 0.34                # track centre from the middle, track width
# LP_TRACKS=short: a shorter run, five road wheels (asked for the Scorcher, 2026-11-08, then dropped: "Never mind about the
# tracks if this risks inflating mod size": a base and a track animation of its own). Both units share the long run.
SHORT = os.environ.get("LP_TRACKS") == "short"
IDL = (0.8, 0.21, 0.19) if SHORT else (1.0, 0.21, 0.19)     # idler: y, z, radius (front)
SPR = (-0.84, 0.25, 0.22) if SHORT else (-1.0, 0.25, 0.22)  # sprocket: y, z, radius (rear, a little higher)
ROAD = [(-0.58 + k * 0.29, 0.12, 0.1) for k in range(5)] if SHORT else [(-0.72 + k * 0.29, 0.12, 0.1) for k in range(6)]
TRACK = 4                          # frames a direction: one shoe pitch over the cycle

def chassis():
    for sx in (-1, 1):
        x = sx * TX
        # Track frame: a beam between idler and sprocket, the road wheels under it, two return rollers on top.
        box(0.12, IDL[0] - SPR[0] - 0.1, 0.12, x, (IDL[0] + SPR[0]) / 2, 0.17, M["dark"], bevel=0.01)
        for y, z, r in ROAD:
            axle_cyl(r, TW * 0.7, x, y, z, M["dark"], bevel=0.01)
            axle_cyl(r * 0.45, TW * 0.72, x, y, z, M["steel"])
        for y in (-0.35, 0.4):
            axle_cyl(0.05, TW * 0.4, x, y, 0.41, M["steel"])
        y, z, r = IDL
        axle_cyl(r, TW * 0.6, x, y, z, M["dark"], bevel=0.015)
        axle_cyl(r * 0.5, TW * 0.62, x, y, z, M["steel"])
        y, z, r = SPR                                                            # the sprocket, toothed
        axle_cyl(r * 0.85, TW * 0.5, x, y, z, M["dark"], bevel=0.01)
        for k in range(14):
            a = 2 * math.pi * k / 14
            oriented("cube", (x, y + math.cos(a) * r * 0.88, z + math.sin(a) * r * 0.88), (a - math.pi / 2, 0, 0),
                     (TW * 0.42, 0.045, 0.05), M["steel"], size=1)
        axle_cyl(r * 0.35, TW * 0.6, x, y, z, M["rust"])
    # The tub between the tracks; the engine in the open on it (the user, 2026-11-08, choosing the exposed Killdozer over
    # the armoured box: "Maybe we try B"): the block, its valve covers in the old machine's yellow, intake and exhaust
    # manifolds, a turbo, an air cleaner with its pre-cleaner bowl; the radiator at the front with its fins, a fan shroud
    # behind it and a grille guard of bars before it; the fuel tank at the back.
    box(2 * TX - TW - 0.06, 2.0, 0.34, 0, -0.02, 0.2, M["dark"], bevel=0.02)
    EY = 0.42                                                                    # the engine's middle
    # (A dark engine read as clutter at game scale, beside vanilla's tank: bare steel, the old yellow, amber parts.)
    box(0.46, 0.66, 0.24, 0, EY, 0.54, M["steel"], bevel=0.02)                   # the block
    for k in range(5):
        box(0.5, 0.02, 0.18, 0, EY - 0.24 + k * 0.12, 0.57, M["plate"], bevel=0.004)
    # Valve covers ribbed across, a filler cap each (plain blocks read as two yellow lumps); bolts down their flanks.
    for sx in (-1, 1):
        box(0.18, 0.62, 0.07, sx * 0.11, EY, 0.78, M["yellow"], bevel=0.025)
        for k in range(7):
            box(0.17, 0.018, 0.02, sx * 0.11, EY - 0.27 + k * 0.09, 0.85, M["yellow"], bevel=0.006)
        cyl(0.03, 0.04, sx * 0.11, EY + 0.2, 0.86, M["dark"], bevel=0.006)
        for k in range(6):
            V.bolt(sx * 0.1 + sx * 0.08, EY - 0.25 + k * 0.1, 0.83, rot=(0, sx * math.pi / 2, 0))
    # A belt over the crank, the fan and the alternator at the engine's front.
    for (x, z, r) in ((0.0, 0.6, 0.07), (0.0, 0.8, 0.06), (0.17, 0.72, 0.04)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r, depth=0.03, location=(x, EY + 0.35, z), rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["bright"])
    for a, b in (((0.0, 0.53), (0.0, 0.86)), ((0.07, 0.6), (0.2, 0.72)), ((0.06, 0.8), (0.2, 0.74))):
        rod((a[0], EY + 0.37, a[1]), (b[0], EY + 0.37, b[1]), 0.008, M["rubber"])
    box(0.1, 0.12, 0.1, 0.17, EY + 0.28, 0.67, M["dark"], bevel=0.012)                                  # alternator
    for k in range(6):                                                           # intake runners to their log
        y = EY - 0.25 + k * 0.1
        rod((0.18, y, 0.74), (0.28, y, 0.7), 0.02, M["steel"])
    rod((0.29, EY - 0.3, 0.7), (0.29, EY + 0.3, 0.7), 0.04, M["bright"])
    for k in range(6):                                                           # exhaust manifold, rusted
        y = EY - 0.25 + k * 0.1
        rod((-0.18, y, 0.72), (-0.28, y, 0.66), 0.022, M["rust"])
    rod((-0.29, EY - 0.3, 0.66), (-0.29, EY + 0.3, 0.66), 0.04, M["rust"])
    # The turbo up on the exhaust log, its outlet along the engine (pointing sideways it read as a stray pipe).
    V.spun([(-0.04, 0.0), (0.04, 0.0), (0.04, 0.08), (-0.04, 0.08)], -0.26, EY + 0.3, 0.8, M["rust"], steps=32)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.035, depth=0.12, location=(-0.26, EY + 0.22, 0.8), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(M["rust"])
    cyl(0.09, 0.26, 0.3, EY + 0.3, 0.72, M["amber"], bevel=0.01)                  # air cleaner
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, location=(0.3, EY + 0.3, 1.02), segments=32, ring_count=16)
    o = V.obj(); o.scale = (1, 1, 0.8); o.data.materials.append(M["glass"])
    rod((0.3, EY + 0.3, 0.72), (0.29, EY + 0.25, 0.7), 0.03, M["dark"])
    for p0, p1 in (((0.12, EY + 0.34, 0.82), (0.2, 0.88, 0.7)), ((-0.12, EY + 0.34, 0.82), (-0.18, 0.88, 0.5))):
        rod(p0, p1, 0.026, M["rubber"])                                         # radiator hoses
    # Radiator, fan shroud, grille guard.
    RY = 0.9
    box(0.72, 0.12, 0.44, 0, RY, 0.38, M["amber"], bevel=0.015)
    for k in range(16):
        box(0.012, 0.13, 0.4, -0.33 + k * 0.044, RY + 0.005, 0.4, M["dark"], bevel=0.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.02, location=(0, RY - 0.1, 0.6), rotation=(math.pi / 2, 0, 0),
                                     major_segments=40, minor_segments=8)
    V.obj().data.materials.append(M["plate"])
    for k in range(7):
        x = -0.33 + k * 0.11
        rod((x, RY + 0.12, 0.36), (x, RY + 0.12, 0.84), 0.016, M["bright"])
    for z in (0.4, 0.82):
        rod((-0.36, RY + 0.12, z), (0.36, RY + 0.12, z), 0.02, M["bright"])
    box(0.9, 0.36, 0.3, 0, -0.84, 0.5, M["rust"], bevel=0.03)                     # fuel tank
    cyl(0.04, 0.03, 0.3, -0.84, 0.8, M["steel"])
    # Two stacks up off the exhaust log, one leaning, mufflers on them.
    # Their tops heat-blued, a flap cap on each, hinged open.
    for (x, y, top, r) in ((-0.29, EY + 0.18, 1.4, 0.04), (-0.29, EY - 0.18, 1.3, 0.036)):
        rod((x, y, 0.66), (x - 0.02, y, top - 0.2), r, M["rust"])
        rod((x - 0.015, y, top - 0.2), (x - 0.02, y, top), r, M["heat"])
        cyl(r * 1.9, 0.2, x - 0.01, y, 0.86, M["dark"], bevel=0.01)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r * 1.2, depth=0.008, location=(x - 0.02, y - r, top + r * 0.9),
                                            rotation=(math.radians(-55), 0, 0))
        V.obj().data.materials.append(M["dark"])
    # Rock guards over the idlers: plates curved over their tops.
    for sx in (-1, 1):
        y, z, r = IDL
        V.spun([(-TW / 2 - 0.01, r + 0.07), (TW / 2 + 0.01, r + 0.07), (TW / 2 + 0.01, r + 0.095), (-TW / 2 - 0.01, r + 0.095)],
               sx * TX, y, z, M["plate"], steps=24, a0=20, a1=110)
    # (Track guards over the top run, wide pale plates, read as a toy at the first look: gone, as a dozer has none.)

base = V.group(chassis)

# The tracks: shoes round each side's loop, posed per frame.
def loop_points(steps=200):
    """The loop's centreline in (y, z): the bottom run, round the sprocket, the top run, round the idler."""
    (yi, zi, ri), (ys, zs, rs) = IDL, SPR
    ri += 0.02; rs += 0.02
    pts = []
    for k in range(steps):
        f = k / steps
        pts.append((yi + (ys - yi) * f, (zi - ri) + ((zs - rs) - (zi - ri)) * f))
    for k in range(steps):
        a = math.radians(270 - 180 * k / steps)
        pts.append((ys + math.cos(a) * rs, zs + math.sin(a) * rs))
    for k in range(steps):
        f = k / steps
        pts.append((ys + (yi - ys) * f, (zs + rs) + ((zi + ri) - (zs + rs)) * f))
    for k in range(steps):
        a = math.radians(90 - 180 * k / steps)
        pts.append((yi + math.cos(a) * ri, zi + math.sin(a) * ri))
    return pts
LOOP = loop_points()
SEG = [math.dist(LOOP[k], LOOP[(k + 1) % len(LOOP)]) for k in range(len(LOOP))]
LEN = sum(SEG)
NSHOE = int(LEN / 0.11)
PITCH = LEN / NSHOE
def at(s):
    """Position and tangent angle at distance s along the loop."""
    s %= LEN; k = 0
    while s > SEG[k]:
        s -= SEG[k]; k += 1
    (y0, z0), (y1, z1) = LOOP[k], LOOP[(k + 1) % len(LOOP)]
    f = s / SEG[k]
    return (y0 + (y1 - y0) * f, z0 + (z1 - z0) * f), math.atan2(z1 - z0, y1 - y0)

def make_shoe():
    """One shoe: a plate and a grouser across it on its outer face, merged."""
    # (Posed by its tangent, a shoe's local +z faces out of the loop: the grouser goes there.)
    a = box(TW, PITCH * 0.86, 0.026, 0, 0, -0.013, M["tread"], bevel=0.004)
    # (Grousers worn bright, where the ground polishes them: dark shoes alone made the tracks a dark mass.)
    b = box(TW * 0.96, 0.02, 0.022, 0, 0, 0.013, M["steel"], bevel=0.003)
    bpy.ops.object.select_all(action="DESELECT"); a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a; bpy.ops.object.join()
    return a
proto = make_shoe()
shoes = []
for sx in (-1, 1):
    for k in range(NSHOE):
        o = proto.copy(); V.scene.collection.objects.link(o); shoes.append((o, sx, k))
bpy.data.objects.remove(proto)
anim = [o for o, _, _ in shoes]

def pose(f):
    """Frame f of TRACK: every shoe moved f / TRACK of a pitch backward along its loop (the bottom run goes rearward)."""
    for o, sx, k in shoes:
        (y, z), ang = at((k + f / TRACK) * PITCH)
        o.location = (sx * TX, y, z); o.rotation_euler = (ang, 0, 0)
pose(0)

def dozer():
    """The Killdozer as the user chose it (2026-11-08: "Maybe we try B", the exposed machine over the armoured box: the
    box read as "a block of cheddar" and then a quilt): the machinery in the open (the base's engine), armour only where
    it would be: the cab at the back shut in irregular plates, warm, slit, a domed amber cupola; plates bolted over the
    engine's flanks with gaps; the blade thick and ribbed on its push arms and rams; a ripper at the back."""
    # The cab a low faceted casemate, not a box (the user: "The cube cabin looks a little cartoonish": tall and upright
    # with a dome on it): its sides leaning in hard, its front sloped well back, its rear a little; a narrow roof.
    CW, CY0, CY1, CZ0, CZ1 = 1.14, -1.02, -0.08, 0.5, 0.98
    IN, FS, RS = 0.2, 0.26, 0.1                                   # the roof's inset at the sides, front and rear
    b = {"lr": (-CW / 2, CY0, CZ0), "rr": (CW / 2, CY0, CZ0), "rf": (CW / 2, CY1, CZ0), "lf": (-CW / 2, CY1, CZ0)}
    t = {"lr": (-CW / 2 + IN, CY0 + RS, CZ1), "rr": (CW / 2 - IN, CY0 + RS, CZ1), "rf": (CW / 2 - IN, CY1 - FS, CZ1),
         "lf": (-CW / 2 + IN, CY1 - FS, CZ1)}
    faces = {"left": (b["lr"], b["lf"], t["lf"], t["lr"]), "right": (b["rf"], b["rr"], t["rr"], t["rf"]),
             "front": (b["lf"], b["rf"], t["rf"], t["lf"]), "rear": (b["rr"], b["lr"], t["lr"], t["rr"]),
             "roof": (t["lr"], t["rr"], t["rf"], t["lf"])}
    core = M["plate"]
    for f in faces.values():
        V.panel(list(f), core, t=0.04)
    # Close shades, so the plates read as one patched skin and not a checkerboard (rust, a darker rust, dark steel, a
    # dull amber; bright amber and bare steel alternating were "a little exaggerated").
    warm = [M["rust"], M["rust"], M["rust2"], M["rust2"], M["plate"], M["amber_dull"]]
    inside = (0, (CY0 + CY1) / 2, 0.7)
    for name, nx, ny, seed in (("left", 3, 2, 21), ("right", 3, 1, 23), ("front", 2, 2, 25), ("rear", 2, 1, 27), ("roof", 2, 2, 29)):
        V.plated(*faces[name], warm if name != "roof" else [M["plate"], M["rust2"], M["plate"]], nx=nx, ny=ny, seed=seed, inside=inside)
    for a, c in ((b["lf"], t["lf"]), (b["rf"], t["rf"]), (b["lr"], t["lr"]), (b["rr"], t["rr"]), (t["lf"], t["rf"]),
                 (t["lr"], t["rr"]), (t["lf"], t["lr"]), (t["rf"], t["rr"])):
        rod(a, c, 0.035, core)                                                   # welded edges
    # Slits under brows in the sloped front, one in each flank.
    fz = CZ0 + (CZ1 - CZ0) * 0.55; fy = CY1 - FS * 0.55
    for x in (-0.2, 0.0, 0.2):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, fy + 0.02, fz), rotation=(math.atan2(FS, CZ1 - CZ0), 0, 0))
        o = V.obj(); o.scale = (0.14, 0.05, 0.035); o.data.materials.append(M["dark"])
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, fy + 0.05, fz + 0.05), rotation=(math.atan2(FS, CZ1 - CZ0), 0, 0))
        o = V.obj(); o.scale = (0.18, 0.08, 0.016); o.data.materials.append(M["steel"])
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * (CW / 2 - IN * 0.55 + 0.02), -0.5, fz), rotation=(0, sx * math.atan2(IN, CZ1 - CZ0), 0))
        o = V.obj(); o.scale = (0.05, 0.16, 0.035); o.data.materials.append(M["dark"])
    # A low cupola of dark steel with vision blocks round it (an amber dome read as a cherry on a box), the hatch beside
    # it, a caged lamp at each front corner of the roof.
    cx, cy = 0.08, -0.6
    cyl(0.17, 0.09, cx, cy, CZ1 + 0.01, M["plate"], bevel=0.015)
    cyl(0.13, 0.03, cx, cy, CZ1 + 0.1, M["plate"], bevel=0.01)
    for k in range(6):
        a = k * math.pi / 3
        box(0.06, 0.04, 0.04, cx + math.cos(a) * 0.165, cy + math.sin(a) * 0.165, CZ1 + 0.04, M["glass"], rot=a + math.pi / 2, bevel=0.006)
    cyl(0.1, 0.035, -0.2, -0.82, CZ1 + 0.01, M["plate"], bevel=0.01)
    for k in range(6):
        a = k * math.pi / 3
        V.bolt(-0.2 + math.cos(a) * 0.08, -0.82 + math.sin(a) * 0.08, CZ1 + 0.05)
    for sx in (-1, 1):
        x, y, z = sx * (CW / 2 - IN - 0.05), CY1 - FS - 0.05, CZ1 + 0.01
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.04, depth=0.07, location=(x, y + 0.02, z + 0.04), rotation=(math.pi / 2 - 0.3, 0, 0))
        V.obj().data.materials.append(M["dark"])
        cyl(0.032, 0.006, x, y + 0.06, z + 0.035, M["lamp"], rot=(math.pi / 2 - 0.3, 0, 0))
        for dx in (-0.022, 0, 0.022):
            rod((x + dx, y + 0.07, z), (x + dx, y + 0.07, z + 0.085), 0.004, M["steel"])
    # Plates bolted over the engine's flanks, angled, with gaps between them.
    for sx in (-1, 1):
        for k, (y, h, m) in enumerate(((0.12, 0.3, M["rust"]), (0.46, 0.26, M["amber"]), (0.76, 0.24, M["plate"]))):
            x0 = sx * 0.4
            V.panel([(x0, y - 0.13, 0.5), (x0, y + 0.13, 0.5), (sx * 0.34, y + 0.12, 0.5 + h), (sx * 0.34, y - 0.12, 0.5 + h)], m,
                    t=0.03, bevel=0.01)
            for z in (0.56, 0.44 + h):
                V.bolt(sx * 0.405, y, z, rot=(0, math.pi / 2, 0))
    # The blade: thick, curved forward across both tracks, ribbed behind, toothed, its edge worn bright, hazard
    # stripes along its top, end bits at each side.
    BY, BZ, BR = 1.72, 0.44, 0.44
    V.spun([(-1.0, BR), (1.0, BR), (1.0, BR + 0.07), (-1.0, BR + 0.07)], 0, BY, BZ, M["plate"], steps=32, a0=145, a1=238)
    # Its face scraped bright where the soil runs over it (a dark blade was one more dark mass).
    V.spun([(-0.97, BR - 0.006), (0.97, BR - 0.006), (0.97, BR + 0.001), (-0.97, BR + 0.001)], 0, BY, BZ, M["scraped"], steps=32,
           a0=150, a1=236)
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):                                                          # ribs behind
        V.spun([(x - 0.03, BR + 0.07), (x + 0.03, BR + 0.07), (x + 0.03, BR + 0.17), (x - 0.03, BR + 0.17)], 0, BY, BZ,
               M["plate"], steps=24, a0=150, a1=232)
    edge = (BY + math.cos(math.radians(238)) * BR, BZ + math.sin(math.radians(238)) * BR)
    box(2.02, 0.07, 0.06, 0, edge[0], edge[1] - 0.03, M["bright"], bevel=0.01)
    for k in range(9):
        box(0.07, 0.07, 0.05, -0.88 + k * 0.22, edge[0] + 0.06, edge[1] - 0.04, M["steel"], bevel=0.012)
    top = (BY + math.cos(math.radians(145)) * (BR + 0.04), BZ + math.sin(math.radians(145)) * (BR + 0.04))
    for k in range(10):
        oriented("cube", (-0.9 + k * 0.2, top[0], top[1] + 0.01), (0, 0, 0), (0.1, 0.05, 0.04),
                 M["yellow"] if k % 2 else M["dark"], size=1)
    # A spill guard over its middle: a frame of bars up from its top.
    for x in (-0.36, -0.12, 0.12, 0.36):
        rod((x, top[0] - 0.02, top[1]), (x, top[0] - 0.08, top[1] + 0.22), 0.016, M["plate"])
    rod((-0.4, top[0] - 0.08, top[1] + 0.22), (0.4, top[0] - 0.08, top[1] + 0.22), 0.02, M["plate"])
    rod((-0.4, top[0] - 0.05, top[1] + 0.11), (0.4, top[0] - 0.05, top[1] + 0.11), 0.014, M["plate"])
    # A single tilt cylinder on the right, from the push arm up to the blade's corner (a real dozer's, and asymmetry).
    rod((0.82, BY - BR - 0.08, 0.36), (0.7, BY - BR - 0.02, BZ + 0.3), 0.04, M["dark"])
    rod((0.76, BY - BR - 0.05, 0.6), (0.7, BY - BR - 0.02, BZ + 0.3), 0.022, M["bright"])
    for sx in (-1, 1):
        V.panel([(sx * 1.0, BY - BR, BZ - 0.25), (sx * 1.0, BY - BR, BZ + 0.25), (sx * 1.0, BY - BR + 0.22, BZ + 0.2),
                 (sx * 1.0, BY - BR + 0.22, BZ - 0.32)], M["plate"], t=0.05)
        # Push arms from the track frames to the blade, the rams from the shell's front to the blade's top.
        rod((sx * TX, 0.1, 0.2), (sx * 0.82, BY - BR - 0.06, 0.3), 0.06, M["plate"])
        # Spikes welded on its top corners.
        tz = BZ + math.sin(math.radians(145)) * (BR + 0.04)
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.035, depth=0.16, location=(sx * 0.95, top[0] + 0.02, tz + 0.1))
        V.obj().data.materials.append(M["scraped"])
        box(0.14, 0.2, 0.14, sx * 0.82, BY - BR - 0.1, 0.24, M["plate"], bevel=0.02)
        # The lift rams, beside the radiator (a dozer's sit there), up to the blade's top.
        rod((sx * 0.45, 0.82, 0.86), (sx * 0.45, BY - BR - 0.1, 0.74), 0.055, M["dark"])
        rod((sx * 0.45, 1.0, 0.82), (sx * 0.45, BY - BR - 0.06, 0.74), 0.03, M["bright"])
    # The back (the user: "The back looks quite bad": a thin bar and a pole for a ripper, a flat wall over it): a
    # counterweight low between the tracks, its lifting eyes; the ripper on a parallelogram, a mounting frame on the tub,
    # upper and lower links each side, a crossbeam, three curved shanks with bright tips, two hydraulic cylinders; on
    # the cab's rear slope tail lamps, a slit behind a mesh guard, grab rails, a rack of jerrycans.
    box(0.82, 0.16, 0.24, 0, CY0 - 0.06, 0.24, M["plate"], bevel=0.02)                # counterweight
    for x in (-0.28, 0.28):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.04, minor_radius=0.012, location=(x, CY0 - 0.06, 0.5), rotation=(math.pi / 2, 0, 0),
                                         major_segments=24, minor_segments=8)
        V.obj().data.materials.append(M["steel"])
    MY = CY0 - 0.16                                                               # the mounting frame's face
    box(0.86, 0.06, 0.36, 0, MY, 0.16, M["plate"], bevel=0.015)
    BYR, BZR = MY - 0.42, 0.3                                                     # the crossbeam
    for sx in (-1, 1):
        x = sx * 0.36
        rod((x, MY, 0.22), (x, BYR, BZR - 0.06), 0.045, M["plate"])                # lower links (amber read as wood)
        rod((x, MY, 0.46), (x, BYR + 0.02, BZR + 0.14), 0.04, M["plate"])          # upper links
        rod((x * 0.6, MY, 0.5), (x * 0.6, BYR + 0.05, BZR + 0.06), 0.05, M["dark"])  # cylinders
        rod((x * 0.6, MY - 0.12, 0.44), (x * 0.6, BYR + 0.05, BZR + 0.06), 0.026, M["bright"])
    box(0.92, 0.14, 0.2, 0, BYR, BZR - 0.06, M["plate"], bevel=0.02)
    for x in (-0.3, 0.0, 0.3):                                                    # shanks: curved, thick, bright tips
        # Down from the beam and curving forward (centred ahead of the beam: the first curved back, out of sight).
        V.spun([(x - 0.035, 0.28), (x + 0.035, 0.28), (x + 0.035, 0.36), (x - 0.035, 0.36)], 0, BYR + 0.32, BZR - 0.06,
               M["plate"], steps=20, a0=178, a1=246)
        tip = (BYR + 0.32 + math.cos(math.radians(246)) * 0.32, BZR - 0.06 + math.sin(math.radians(246)) * 0.32)
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.045, depth=0.12, location=(x, tip[0] + 0.03, tip[1] - 0.02),
                                        rotation=(math.radians(-150), 0, 0))
        V.obj().data.materials.append(M["scraped"])
    # The cab's rear slope.
    ry, rz = CY0 + RS * 0.5, CZ0 + (CZ1 - CZ0) * 0.5
    for sx in (-1, 1):
        box(0.08, 0.03, 0.05, sx * 0.4, CY0 - 0.01, CZ0 + 0.06, M["dark"], bevel=0.006)
        box(0.06, 0.012, 0.035, sx * 0.4, CY0 - 0.026, CZ0 + 0.068, M["tail"], bevel=0.003)
        rod((sx * 0.3, CY0 + 0.02, CZ0 + 0.12), (sx * 0.28, CY0 + RS - 0.02, CZ1 - 0.06), 0.012, M["bright"])   # grab rails
    box(0.3, 0.05, 0.04, 0, ry - 0.02, rz, M["dark"], bevel=0.004)
    for k in range(5):
        rod((-0.15 + k * 0.075, ry - 0.06, rz - 0.06), (-0.15 + k * 0.075, ry - 0.02, rz + 0.1), 0.005, M["steel"])
    for k, m in enumerate((M["red"], M["olive"], M["red"])):                      # jerrycans in a rack
        box(0.09, 0.07, 0.17, -0.12 + k * 0.12, CY0 - 0.08, CZ0 + 0.02, m, bevel=0.01)
    rod((-0.2, CY0 - 0.12, CZ0 + 0.14), (0.2, CY0 - 0.12, CZ0 + 0.14), 0.01, M["steel"])
    # Grubstake's marks: a whip antenna on the cab's rear left with its red pennant (the buggy's), two work lamps on the
    # rear of the roof, a chain hung along the ripper's beam.
    whip(-(CW / 2 - IN) + 0.04, CY0 + RS + 0.04, CZ1)
    for sx in (-1, 1):
        x, y, z = sx * 0.2, CY0 + RS + 0.03, CZ1 + 0.01
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.035, depth=0.06, location=(x, y - 0.02, z + 0.04), rotation=(math.pi / 2 + 0.3, 0, 0))
        V.obj().data.materials.append(M["dark"])
        cyl(0.028, 0.006, x, y - 0.055, z + 0.035, M["lamp"], rot=(math.pi / 2 + 0.3, 0, 0))
    for k in range(14):
        f = k / 13
        bpy.ops.mesh.primitive_torus_add(major_radius=0.022, minor_radius=0.006, location=(-0.4 + 0.8 * f, BYR - 0.08, BZR - 0.1 - 0.08 * math.sin(math.pi * f)),
                                         rotation=(0, math.pi / 2 if k % 2 else 0, 0), major_segments=16, minor_segments=6)
        V.obj().data.materials.append(M["steel"])

def whip(ax, ay, az):
    """Grubstake's whip antenna with its red pennant (the buggy's)."""
    rod((ax, ay, az), (ax - 0.06, ay - 0.1, az + 0.95), 0.012, M["bright"])
    V.panel([(ax - 0.05, ay - 0.085, az + 0.8), (ax - 0.06, ay - 0.1, az + 0.95), (ax - 0.04, ay - 0.36, az + 0.88)], M["rag"], t=0.004)

def scorcher():
    """The Scorcher on the crawler (Grubstake's flamethrower vehicle, Scrap arms): a low open-topped fighting compartment
    at the back in the dozer's patched rust plates, its floor dark inside; the flamethrower forward on it, on a ring behind
    a curved shield, its tube ringed with heat shields, its nozzle bright and its pilot light burning; three pressure tanks
    across the back in hazard red, banded, piped forward to the gun; a spiked ram before the radiator in the blade's place
    (Mad Max, the user's inspiration); the whip and pennant."""
    CW, CY0, CY1, CZ0, CZ1 = 1.14, -1.0, -0.06, 0.5, 0.9
    IN, FS, RS = 0.1, 0.14, 0.04
    b = {"lr": (-CW / 2, CY0, CZ0), "rr": (CW / 2, CY0, CZ0), "rf": (CW / 2, CY1, CZ0), "lf": (-CW / 2, CY1, CZ0)}
    t = {"lr": (-CW / 2 + IN, CY0 + RS, CZ1), "rr": (CW / 2 - IN, CY0 + RS, CZ1), "rf": (CW / 2 - IN, CY1 - FS, CZ1),
         "lf": (-CW / 2 + IN, CY1 - FS, CZ1)}
    faces = {"left": (b["lr"], b["lf"], t["lf"], t["lr"]), "right": (b["rf"], b["rr"], t["rr"], t["rf"]),
             "front": (b["lf"], b["rf"], t["rf"], t["lf"]), "rear": (b["rr"], b["lr"], t["lr"], t["rr"])}
    for f in faces.values():
        V.panel(list(f), M["plate"], t=0.04)
    warm = [M["rust"], M["rust"], M["rust2"], M["rust2"], M["plate"], M["amber_dull"]]
    inside = (0, (CY0 + CY1) / 2, 0.7)
    for name, nx, ny, seed in (("left", 3, 1, 41), ("right", 3, 1, 43), ("front", 2, 1, 45), ("rear", 2, 1, 47)):
        V.plated(*faces[name], warm, nx=nx, ny=ny, seed=seed, inside=inside)
    for a, c in ((t["lf"], t["rf"]), (t["lr"], t["rr"]), (t["lf"], t["lr"]), (t["rf"], t["rr"]), (b["lf"], t["lf"]),
                 (b["rf"], t["rf"]), (b["lr"], t["lr"]), (b["rr"], t["rr"])):
        rod(a, c, 0.035, M["plate"])                                             # its rim and edges, welded
    box(CW - 0.2, CY1 - CY0 - 0.2, 0.02, 0, (CY0 + CY1) / 2, CZ0 + 0.12, M["dark"], bevel=0.005)   # the floor inside
    # Its rear half roofed with plates sloping up to a ridge, a mesh grille between them and the gun, sandbags along its
    # front rim (from above it read as an empty tub).
    ry0, ry1, rz = CY0 + RS + 0.02, -0.5, CZ1 + 0.1
    hw = CW / 2 - IN
    for sx in (-1, 1):
        V.panel([(sx * hw, ry0, CZ1), (sx * hw, ry1, CZ1), (0, ry1, rz), (0, ry0, rz)], M["rust2"] if sx < 0 else M["plate"], t=0.03, bevel=0.01)
        V.plated((sx * hw, ry0, CZ1), (sx * hw, ry1, CZ1), (0, ry1, rz), (0, ry0, rz), [M["rust"], M["plate"], M["amber_dull"]],
                 nx=2, ny=1, seed=51 + sx, inside=(0, (ry0 + ry1) / 2, CZ1 - 0.2))
    rod((0, ry0, rz), (0, ry1, rz), 0.03, M["plate"])
    for k in range(7):
        x = -hw + 0.04 + k * (2 * hw - 0.08) / 6
        rod((x, ry1, CZ1 + 0.02), (x, -0.42, CZ1 + 0.02), 0.007, M["steel"])
    for y in (ry1, -0.46, -0.42):
        rod((-hw, y, CZ1 + 0.02), (hw, y, CZ1 + 0.02), 0.007, M["steel"])
    for k in range(5):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=16, ring_count=8, location=(-0.4 + k * 0.2, CY1 - FS - 0.03, CZ1 + 0.03))
        o = V.obj(); o.scale = (0.1, 0.06, 0.045); o.data.materials.append(M["canvas"])
    box(0.2, 0.18, 0.16, -0.3, -0.75, CZ0 + 0.14, M["olive"], bevel=0.015)                         # a crate inside
    box(0.14, 0.22, 0.1, 0.32, -0.7, CZ0 + 0.14, M["dark"], bevel=0.012)
    # The flamethrower, big enough to read (a thin dark tube was lost over the engine, the first look): a ring at the
    # compartment's front, a chunky rounded housing on it, the tube thick and raised, heat shield rings bright along it,
    # the nozzle, the pilot light under it; a wide curved shield before the housing.
    GX, GY, GZ = 0.0, -0.22, CZ1 + 0.02
    cyl(0.2, 0.05, GX, GY, GZ, M["plate"], bevel=0.01)
    box(0.3, 0.38, 0.2, GX, GY - 0.02, GZ + 0.05, M["plate"], bevel=0.05)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.1, depth=0.34, location=(GX, GY + 0.02, GZ + 0.27), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(M["amber_dull"])
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.05, depth=0.3, location=(GX + sx * 0.12, GY - 0.02, GZ + 0.22), rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["red"])
    a = math.radians(8)
    p0 = mathutils.Vector((GX, GY + 0.18, GZ + 0.27)); d = mathutils.Vector((0, math.cos(a), math.sin(a)))
    # A slotted heat shield over the tube (rings along it read as a coil spring at game scale), the nozzle flared and
    # scorched (nothing at the front said flame).
    rod(tuple(p0), tuple(p0 + d * 0.8), 0.045, M["dark"])
    rod(tuple(p0 + d * 0.1), tuple(p0 + d * 0.68), 0.075, M["steel"])
    u = mathutils.Vector((1, 0, 0)); v = d.cross(u)
    for k in range(10):
        ang = 2 * math.pi * k / 10; off = (u * math.cos(ang) + v * math.sin(ang)) * 0.077
        for s0, s1 in ((0.14, 0.36), (0.42, 0.64)):
            rod(tuple(p0 + d * s0 + off), tuple(p0 + d * s1 + off), 0.009, M["dark"])
    for s0 in (0.1, 0.68):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.078, minor_radius=0.012, location=tuple(p0 + d * s0), rotation=(math.pi / 2 - a, 0, 0),
                                         major_segments=32, minor_segments=8)
        V.obj().data.materials.append(M["bright"])
    rod(tuple(p0 + d * 0.76), tuple(p0 + d * 0.86), 0.06, M["heat"])
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.06, radius2=0.09, depth=0.1, location=tuple(p0 + d * 0.9),
                                    rotation=(-(math.pi / 2 - a), 0, 0))
    V.obj().data.materials.append(M["heat"])
    q = p0 + d * 0.84 + mathutils.Vector((0, 0, -0.1))
    box(0.07, 0.1, 0.06, q.x, q.y, q.z - 0.02, M["dark"], bevel=0.008)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.026, location=(q.x, q.y + 0.06, q.z + 0.01)); V.obj().data.materials.append(M["pilot"])
    V.spun([(-0.32, 0.24), (0.32, 0.24), (0.32, 0.28), (-0.32, 0.28)], GX, GY + 0.02, GZ + 0.12, M["amber_dull"], steps=32, a0=-30, a1=62)
    rod((GX - 0.16, GY - 0.2, GZ + 0.2), (GX - 0.2, GY - 0.36, GZ + 0.2), 0.012, M["bright"])      # a grip
    # Its machine gun (the user: "Don't forget the scorcher has a small machine gun too"): a pintle on the compartment's
    # rear right corner, the gun behind a small shield, its ammo box and belt, the buggy's.
    mx, my, mz = CW / 2 - IN - 0.08, CY0 + RS + 0.14, CZ1
    # (Too small to see at game scale, the first: the buggy's gun at its own size.)
    rod((mx, my, mz), (mx, my + 0.02, mz + 0.22), 0.035, M["steel"])
    box(0.13, 0.4, 0.1, mx, my + 0.02, mz + 0.2, M["dark"], bevel=0.015)
    rod((mx, my + 0.2, mz + 0.26), (mx, my + 0.8, mz + 0.26), 0.034, M["dark"])
    rod((mx, my + 0.66, mz + 0.26), (mx, my + 0.84, mz + 0.26), 0.044, M["steel"])
    for y in (0.3, 0.38, 0.46, 0.54):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.038, minor_radius=0.008, location=(mx, my + y, mz + 0.26), rotation=(math.pi / 2, 0, 0),
                                         major_segments=24, minor_segments=8)
        V.obj().data.materials.append(M["steel"])
    box(0.36, 0.03, 0.2, mx, my + 0.2, mz + 0.17, M["rust2"], bevel=0.01)
    box(0.12, 0.11, 0.11, mx + 0.13, my - 0.04, mz + 0.16, M["olive"], bevel=0.012)
    # Three pressure tanks across the back, domed, banded, a gauge on the middle one; pipes forward to the gun.
    for k, z in enumerate((0.62, 0.86, 0.74)):
        y = CY0 - 0.14 - (0.0 if k < 2 else 0.2)
        x0, zz = (-0.02, z) if k < 2 else (0.0, 0.62)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.11, depth=0.78, location=(x0, y, zz), rotation=(0, math.pi / 2, 0))
        V.obj().data.materials.append(M["red"])
        for sx in (-1, 1):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(x0 + sx * 0.39, y, zz), segments=32, ring_count=16)
            o = V.obj(); o.scale = (0.45, 1, 1); o.data.materials.append(M["red"])
        for x in (-0.22, 0.22):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.112, minor_radius=0.01, location=(x0 + x, y, zz), rotation=(0, math.pi / 2, 0),
                                             major_segments=32, minor_segments=8)
            V.obj().data.materials.append(M["dark"])
    box(0.9, 0.06, 0.5, 0, CY0 - 0.04, 0.5, M["plate"], bevel=0.01)                                # the tanks' cradle
    cyl(0.035, 0.02, 0.1, CY0 - 0.14, 0.98, M["bright"], rot=(math.pi / 2, 0, 0))                    # gauge
    for x in (-0.06, 0.06):
        rod((x, CY0 - 0.08, 0.9), (x, -0.4, CZ1 + 0.06), 0.016, M["rubber"])
        rod((x, -0.4, CZ1 + 0.06), (GX + x * 0.5, GY - 0.12, GZ + 0.12), 0.016, M["rubber"])
    # A beak across the front, as a tank's glacis (the user: "give it a beak horizontally, with angles like a real tank";
    # a V of plates and then a push plate before): a lower plate from under the hull up and forward to a ridge, an upper
    # plate from the ridge back up over the radiator, both the hull's full width; cheeks closing its sides; plates
    # welded over it, a towing eye each side under the ridge, the headlamps in guards on the upper plate.
    HW, YR, ZR = TX + TW / 2 + 0.02, 1.2, 0.36          # half width, the ridge's y and height
    lo = [(-HW, 0.78, 0.08), (HW, 0.78, 0.08), (HW, YR, ZR), (-HW, YR, ZR)]
    up = [(-HW, YR, ZR), (HW, YR, ZR), (HW * 0.82, 0.62, 0.86), (-HW * 0.82, 0.62, 0.86)]
    V.panel(lo, M["plate"], t=0.05, bevel=0.012)
    V.panel(up, M["plate"], t=0.05, bevel=0.012)
    V.plated(*up, [M["rust"], M["rust2"], M["plate"], M["amber_dull"]], nx=3, ny=2, seed=61, inside=(0, 0.8, 0.4))
    V.plated(*lo, [M["rust2"], M["plate"]], nx=2, ny=1, seed=63, inside=(0, 0.8, 0.4))
    for sx in (-1, 1):
        V.panel([(sx * HW, 0.78, 0.08), (sx * HW, YR, ZR), (sx * HW * 0.82, 0.62, 0.86), (sx * HW, 0.62, 0.5)], M["rust2"], t=0.04)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.014, location=(sx * 0.5, YR - 0.06, ZR - 0.1),
                                         rotation=(0, math.pi / 2, 0), major_segments=24, minor_segments=8)
        V.obj().data.materials.append(M["steel"])
        x, y, z = sx * 0.55, 0.95, 0.64
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.045, depth=0.07, location=(x, y, z + 0.03), rotation=(math.pi / 2 - 0.6, 0, 0))
        V.obj().data.materials.append(M["dark"])
        cyl(0.036, 0.006, x, y + 0.035, z + 0.06, M["lamp"], rot=(math.pi / 2 - 0.6, 0, 0))
        for dx in (-0.025, 0, 0.025):
            rod((x + dx, y + 0.06, z + 0.02), (x + dx, y + 0.02, z + 0.1), 0.004, M["steel"])
    rod((-HW, YR, ZR), (HW, YR, ZR), 0.04, M["plate"])                                              # the ridge, welded
    # Spare track links hung across the upper plate as extra armour (a tank's habit), two runs on hooks, a little apart,
    # breaking up its broad face.
    P0, P1 = mathutils.Vector(up[0]), mathutils.Vector(up[3])              # the plate's left edge, ridge to top
    Q0 = mathutils.Vector(up[1])
    nrm = (Q0 - P0).cross(P1 - P0).normalized()
    if nrm.dot(mathutils.Vector((0, 1, 1))) < 0: nrm = -nrm
    rise = (P1 - P0).normalized()
    tilt = math.atan2(rise.z, rise.y)
    for xc in (-0.42, 0.36):
        # (Flat and dark they hardly showed, the first look: bigger, standing off, their grousers bright.)
        for k in range(6):
            c = P0.lerp(P1, 0.1 + k * 0.14); c.x = xc
            c = c + nrm * 0.08
            bpy.ops.mesh.primitive_cube_add(size=1, location=tuple(c), rotation=(tilt - math.pi / 2, 0, 0))
            o = V.obj(); o.scale = (0.38, 0.045, 0.11); o.data.materials.append(M["tread"])
            bpy.ops.mesh.primitive_cube_add(size=1, location=tuple(c + nrm * 0.03), rotation=(tilt - math.pi / 2, 0, 0))
            o = V.obj(); o.scale = (0.36, 0.02, 0.025); o.data.materials.append(M["bright"])
        for f in (0.1, 0.86):
            h = P0.lerp(P1, f); h.x = xc; h = h + nrm * 0.05
            box(0.06, 0.04, 0.04, h.x - 0.12, h.y, h.z - 0.02, M["bright"], bevel=0.006)
            box(0.06, 0.04, 0.04, h.x + 0.12, h.y, h.z - 0.02, M["bright"], bevel=0.006)
    whip(-(CW / 2 - IN) + 0.04, CY0 + RS + 0.04, CZ1)                          # the left corner: the gun has the right

MODULES = {"dozer": dozer, "scorcher": scorcher}
which = os.environ.get("LP_MODULES", ",".join(MODULES)).split(",")
modules = {n: V.group(MODULES[n]) for n in which if n}
V.finish(mud=0.85, mud_top=0.55)          # mud on the tracks, the blade's foot, the underside (a dozer's is never clean)
# LP_WRECK=<module>: that unit's wreck (4 directions, its shadow in the picture), then stop.
if os.environ.get("LP_WRECK"):
    # The left track thrown: its shoes gone, the frame on its road wheels.
    left = {id(o) for o, sx, k in shoes if sx < 0}
    V.wreck(base + anim + modules[os.environ["LP_WRECK"]], out, seed=7, tiles=3, margin=1.2, strip=lambda o: id(o) in left)
    print("crawler wreck:", os.environ["LP_WRECK"], "to", out); sys.exit(0)
rig = V.light(3, 1.2)
# LP_ZOOM=k: the camera k times closer (close looks; the sheets want 1).
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, animated=anim, frames=TRACK, rebuild=pose, light_rig=rig)
print("crawler:", N, "directions,", NSHOE, "shoes a side, to", out)
