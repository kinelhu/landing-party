"""Grubstake's hauler: the convoy truck that carries a camp's exports to the uplink (the unit pass, 2026-11-08, after the
buggies and the crawler). A six-wheeled scrap truck: a ladder frame on three axles, the buggy's pneumatic wheels a size
up; an armoured cab forward, mesh over its slit windows, a bull bar, stacks behind it, a roof gun (it is lightly armed),
the whip and pennant; the bed a module of its own (stake sides, crates, banded drums, sacks under a lashed tarp), so a
later load can swap it.

    /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/hauler.py -- <out_dir> [N=64]
    then one sheet.py run a part: out/base, out/bed
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import vehicle as V
from vehicle import M, box, rod, cyl, axle_cyl, bolt

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
N = int(args[1]) if len(args) > 1 else 64
V.setup()

# Forward along +y. About 2.7 tiles long and 1.6 wide (its selection box 2 by 2.4, a size over the car's).
WR, WT = 0.27, 0.24
TRACK = 1.36
# A bonnet truck (the first, a cab-over box, read as the "cube cabin" the user called cartoonish on the dozer): the
# engine under a long hood over the front axle, the cab set back and lower, the bed behind.
AXLES = (0.9, -0.55, -1.08)           # front, then the rear pair
ZF = 0.36                              # the frame's rails
YC0, YC1 = 0.0, 0.5                    # the cab's back and front
YH1 = 1.36                             # the hood's front (the grille)

def chassis():
    for y in AXLES:
        for sx in (-1, 1):
            V.wheel(sx * TRACK / 2, y, sx, WR, WT)
        rod((-TRACK / 2 + WT / 2, y, WR), (TRACK / 2 - WT / 2, y, WR), 0.035, M["dark"])          # the axle
        box(0.5, 0.16, 0.1, 0, y, WR - 0.04, M["dark"], bevel=0.02)                              # its diff
        for sx in (-1, 1):                                                                       # leaf springs
            for k in range(3):
                box(0.06, 0.52 - k * 0.1, 0.018, sx * 0.34, y, ZF - 0.07 - k * 0.02, M["steel"], bevel=0.004)
    for sx in (-1, 1):                                                                           # the rails
        box(0.08, 2.8, 0.14, sx * 0.34, 0.0, ZF - 0.05, M["plate"], bevel=0.01)
    for y in (1.3, 0.5, -0.1, -0.8, -1.35):
        box(0.7, 0.06, 0.08, 0, y, ZF - 0.03, M["plate"], bevel=0.008)
    # A mud flap behind each rear pair (the front fenders are the hood's).
    for sx in (-1, 1):
        box(WT + 0.02, 0.02, 0.24, sx * TRACK / 2, AXLES[2] - WR - 0.08, 0.14, M["rubber"], bevel=0.004)
    # The hood: a long box of plates over the engine, its top a little domed, louvres down its sides, the radiator grille
    # at its front between the front fenders; the fenders sweeping over the wheels and down to running boards.
    HW, HZ = 0.36, 0.84
    for sx in (-1, 1):
        V.panel([(sx * HW, YC1, ZF + 0.06), (sx * HW, YH1, ZF + 0.06), (sx * (HW - 0.04), YH1, HZ), (sx * (HW - 0.04), YC1, HZ + 0.04)],
                M["amber"], t=0.03)
        for k in range(6):
            box(0.012, 0.06, 0.16, sx * (HW + 0.005), YC1 + 0.2 + k * 0.09, ZF + 0.3, M["dark"], bevel=0.002)
    # The hood in Grubstake's amber, a patch or two of rust on it (both dark rectangles, bed and cab, it was the least
    # distinctive of the faction's vehicles: the amber its mark, as the buggy's cage).
    V.panel([(-HW + 0.04, YC1, HZ + 0.04), (HW - 0.04, YC1, HZ + 0.04), (HW - 0.04, YH1, HZ), (-HW + 0.04, YH1, HZ)], M["amber"], t=0.03)
    rod((0, YC1, HZ + 0.08), (0, YH1, HZ + 0.04), 0.02, M["amber"])                             # the hood's seam
    V.plated((-HW + 0.04, YC1, HZ + 0.04), (HW - 0.04, YC1, HZ + 0.04), (HW - 0.04, YH1, HZ), (-HW + 0.04, YH1, HZ),
             [M["amber"], M["amber"], M["amber"], M["rust"]], nx=2, ny=2, seed=81, inside=(0, 0.9, 0.5))
    box(HW * 2 - 0.02, 0.06, HZ - ZF - 0.06, 0, YH1 + 0.02, ZF + 0.06, M["dark"], bevel=0.01)       # grille
    for k in range(9):
        box(0.012, 0.07, HZ - ZF - 0.12, -HW + 0.08 + k * (HW * 2 - 0.16) / 8, YH1 + 0.04, ZF + 0.09, M["bright"], bevel=0.0)
    for sx in (-1, 1):
        V.spun([(-WT / 2 - 0.03, WR + 0.03), (WT / 2 + 0.03, WR + 0.03), (WT / 2 + 0.03, WR + 0.055), (-WT / 2 - 0.03, WR + 0.055)],
               sx * TRACK / 2, AXLES[0], WR, M["plate"], steps=32, a0=55, a1=130)  # (rust and wide, seen from above they made drums of the wheels)
        box(0.08, 0.04, 0.3, sx * (HW + 0.06), AXLES[0], ZF + 0.12, M["plate"], bevel=0.006)        # fender stay
        box(0.24, YC1 - YC0 + 0.12, 0.03, sx * (TRACK / 2), (YC0 + YC1) / 2, ZF + 0.02, M["plate"], bevel=0.006)  # running board
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.07, depth=0.08, location=(sx * (TRACK / 2 - 0.05), AXLES[0] + 0.2, WR * 2 + 0.12),
                                            rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["dark"])
        cyl(0.058, 0.006, sx * (TRACK / 2 - 0.05), AXLES[0] + 0.245, WR * 2 + 0.12, M["lamp"], rot=(math.pi / 2, 0, 0))
    # The cab, set back, lower: plates leaning in, a split windscreen sloped back under mesh, side windows barred.
    W0, W1, Z0, Z1 = 1.22, 1.06, ZF + 0.08, 1.02
    b = {"lr": (-W0 / 2, YC0, Z0), "rr": (W0 / 2, YC0, Z0), "rf": (W0 / 2, YC1, Z0), "lf": (-W0 / 2, YC1, Z0)}
    t = {"lr": (-W1 / 2, YC0, Z1), "rr": (W1 / 2, YC0, Z1), "rf": (W1 / 2, YC1 - 0.18, Z1), "lf": (-W1 / 2, YC1 - 0.18, Z1)}
    faces = {"left": (b["lr"], b["lf"], t["lf"], t["lr"]), "right": (b["rf"], b["rr"], t["rr"], t["rf"]),
             "front": (b["lf"], b["rf"], t["rf"], t["lf"]), "rear": (b["rr"], b["lr"], t["lr"], t["rr"]),
             "roof": (t["lr"], t["rr"], t["rf"], t["lf"])}
    for f in faces.values():
        V.panel(list(f), M["plate"], t=0.04)
    warm = [M["rust"], M["rust2"], M["amber_dull"], M["plate"]]
    inside = (0, (YC0 + YC1) / 2, 0.7)
    for name, nx, ny, seed in (("left", 2, 2, 71), ("right", 2, 2, 73), ("roof", 2, 1, 77)):
        V.plated(*faces[name], warm if name != "roof" else [M["plate"], M["rust2"]], nx=nx, ny=ny, seed=seed, inside=inside)
    for a, c in ((b["lf"], t["lf"]), (b["rf"], t["rf"]), (b["lr"], t["lr"]), (b["rr"], t["rr"]), (t["lf"], t["rf"]),
                 (t["lr"], t["rr"]), (t["lf"], t["lr"]), (t["rf"], t["rr"])):
        rod(a, c, 0.03, M["plate"])
    fz = HZ + (Z1 - HZ) * 0.5; fy = YC1 - 0.18 * (fz - Z0) / (Z1 - Z0)
    ang = math.atan2(0.18, Z1 - Z0)
    for x in (-0.25, 0.25):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, fy + 0.025, fz), rotation=(ang, 0, 0))
        o = V.obj(); o.scale = (0.42, 0.02, 0.14); o.data.materials.append(M["glass"])
        for k in range(6):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x - 0.18 + k * 0.072, fy + 0.05, fz), rotation=(ang, 0, 0))
            o = V.obj(); o.scale = (0.008, 0.012, 0.16); o.data.materials.append(M["steel"])
    for sx in (-1, 1):
        box(0.03, 0.24, 0.12, sx * (W0 + W1) / 4 + sx * 0.02, 0.26, 0.8, M["glass"], bevel=0.004)
        for k in range(4):
            box(0.012, 0.012, 0.14, sx * (W0 + W1) / 4 + sx * 0.04, 0.17 + k * 0.06, 0.8, M["steel"], bevel=0.0)
    # Bull bar before the grille.
    for z in (0.3, 0.52):
        rod((-0.62, YH1 + 0.12, z), (0.62, YH1 + 0.12, z), 0.032, M["tube"])
    for x in (-0.5, -0.18, 0.18, 0.5):
        rod((x, YH1 + 0.12, 0.2), (x, YH1 + 0.12, 0.58), 0.026, M["tube"])
    for sx in (-1, 1):
        rod((sx * 0.34, YH1 + 0.12, 0.3), (sx * 0.34, YH1 - 0.05, ZF), 0.026, M["tube"])
    # Two stacks behind the cab, heat-blued at the top, rain caps.
    for sx, top in ((-1, 1.5), (1, 1.4)):
        x = sx * 0.5
        rod((x, YC0 - 0.08, ZF + 0.1), (x, YC0 - 0.08, top - 0.2), 0.04, M["rust"])
        rod((x, YC0 - 0.08, top - 0.2), (x, YC0 - 0.08, top), 0.04, M["heat"])
        cyl(0.075, 0.24, x, YC0 - 0.08, 0.7, M["dark"], bevel=0.01)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.05, depth=0.008, location=(x, YC0 - 0.12, top + 0.035), rotation=(math.radians(-55), 0, 0))
        V.obj().data.materials.append(M["dark"])
    # Fuel tanks under the frame each side, a tool box.
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.1, depth=0.36, location=(sx * 0.5, -0.18, ZF - 0.02), rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["red"] if sx < 0 else M["olive"])
    box(0.18, 0.24, 0.12, 0.5, 0.2, ZF - 0.1, M["dark"], bevel=0.01)
    # The roof gun on a pintle behind a small shield, the whip and pennant on the cab's rear left.
    # (At its first size it barely read: the buggy's gun, on a ring over the cab.)
    gx, gy, gz = 0.16, 0.18, Z1
    cyl(0.12, 0.04, gx, gy, gz, M["plate"], bevel=0.008)
    rod((gx, gy, gz), (gx, gy + 0.02, gz + 0.2), 0.035, M["steel"])
    box(0.13, 0.4, 0.1, gx, gy, gz + 0.18, M["dark"], bevel=0.015)
    rod((gx, gy + 0.18, gz + 0.24), (gx, gy + 0.8, gz + 0.24), 0.034, M["dark"])
    rod((gx, gy + 0.66, gz + 0.24), (gx, gy + 0.84, gz + 0.24), 0.044, M["steel"])
    for y in (0.3, 0.38, 0.46, 0.54):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.038, minor_radius=0.008, location=(gx, gy + y, gz + 0.24), rotation=(math.pi / 2, 0, 0),
                                         major_segments=24, minor_segments=8)
        V.obj().data.materials.append(M["steel"])
    box(0.36, 0.03, 0.2, gx, gy + 0.2, gz + 0.15, M["rust2"], bevel=0.01)
    ax, ay = -W1 / 2 + 0.06, YC0 + 0.06
    rod((ax, ay, Z1), (ax - 0.06, ay - 0.1, Z1 + 0.95), 0.012, M["bright"])
    V.panel([(ax - 0.05, ay - 0.085, Z1 + 0.8), (ax - 0.06, ay - 0.1, Z1 + 0.95), (ax - 0.04, ay - 0.36, Z1 + 0.88)], M["rag"], t=0.004)

def bed():
    """The load: a flatbed on the rails with stake sides, its tailgate down a notch; crates of plates stacked, banded
    drums, sacks, a tarp lashed over the front stack, ropes across."""
    Y0, Y1, ZB = -1.42, -0.08, ZF + 0.06
    box(1.36, Y1 - Y0, 0.05, 0, (Y0 + Y1) / 2, ZB, M["plate"], bevel=0.008)
    for k in range(8):
        box(1.36, 0.012, 0.012, 0, Y0 + 0.1 + k * 0.21, ZB + 0.05, M["steel"], bevel=0.0)
    for sx in (-1, 1):                                                                   # stake sides
        for k in range(6):
            y = Y0 + 0.08 + k * (Y1 - Y0 - 0.16) / 5
            box(0.05, 0.05, 0.34, sx * 0.66, y, ZB + 0.05, M["plate"], bevel=0.008)
        for z in (0.2, 0.34):
            box(0.03, Y1 - Y0, 0.05, sx * 0.67, (Y0 + Y1) / 2, ZB + z, M["rust"] if sx < 0 else M["rust2"], bevel=0.006)
    box(1.36, 0.04, 0.3, 0, Y1, ZB + 0.05, M["plate"], bevel=0.008)                   # headboard
    for k in range(4):
        box(1.2, 0.012, 0.02, 0, Y1 + 0.02, ZB + 0.1 + k * 0.06, M["steel"], bevel=0.0)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, Y0 - 0.06, ZB + 0.08), rotation=(math.radians(25), 0, 0))
    o = V.obj(); o.scale = (1.32, 0.04, 0.22); o.data.materials.append(M["rust2"])
    # The load, laid out from the headboard back: a stack of crates under a tarp at the front, drums behind, sacks.
    zb = ZB + 0.05
    crates = ((-0.3, Y1 - 0.24, 0.0, 0.52, 0.38, 0.26, M["amber_dull"]), (0.3, Y1 - 0.24, 0.0, 0.5, 0.38, 0.3, M["olive"]),
              (-0.26, Y1 - 0.24, 0.26, 0.42, 0.32, 0.2, M["olive"]), (0.3, Y1 - 0.66, 0.0, 0.44, 0.36, 0.22, M["amber_dull"]))
    for x, y, z, w, d, h, m in crates:
        box(w, d, h, x, y, zb + z, m, bevel=0.015)
        for dx in (-w / 2 + 0.03, w / 2 - 0.03):
            box(0.025, d + 0.01, h + 0.01, x + dx, y, zb + z, M["dark"], bevel=0.004)
    for k, (x, y) in enumerate(((-0.4, Y1 - 0.68), (-0.14, Y1 - 0.7), (-0.4, Y1 - 0.96), (-0.14, Y1 - 0.98), (0.34, Y1 - 1.06))):
        cyl(0.115, 0.34, x, y, zb, (M["red"], M["olive"], M["rust"], M["red"], M["olive"])[k], bevel=0.01)
        for dz in (0.1, 0.24):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.117, minor_radius=0.01, location=(x, y, zb + dz), major_segments=32, minor_segments=8)
            V.obj().data.materials.append(M["dark"])
    for k in range(3):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=24, ring_count=12, location=(0.36 + (k % 2) * 0.08, Y1 - 0.98 - k * 0.07, zb + 0.06 + k * 0.03))
        o = V.obj(); o.scale = (0.16, 0.1, 0.075); o.data.materials.append(M["canvas"])
    # The tarp over the front stack: dark canvas draped over the crates, folds across it, its sides hanging down to the
    # stakes and roped there (pale and smooth it read as a blob, the first).
    import bmesh
    me = bpy.data.meshes.new("tarp"); bm = bmesh.new()
    nx, ny = 16, 8
    ty0, ty1 = Y1 - 0.48, Y1 - 0.02
    grid = []
    for i in range(nx + 1):
        row = []
        for j in range(ny + 1):
            x = -0.64 + 1.28 * i / nx; y = ty0 + (ty1 - ty0) * j / ny
            ax = abs(x)
            top = zb + (0.5 if (x < 0 and ax < 0.5) else 0.32 if ax < 0.52 else 0.32 - (ax - 0.52) * 2.2)
            fold = 0.025 * math.sin(i * 2.1) + 0.012 * math.sin(j * 2.7 + i)
            row.append(bm.verts.new((x, y, max(zb + 0.12, top) + fold)))
        grid.append(row)
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("tarp", me); V.scene.collection.objects.link(o); me.materials.append(M["tarp"])
    sd = o.modifiers.new("s", "SOLIDIFY"); sd.thickness = 0.015
    sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = 2
    for y in (ty0 + 0.08, (ty0 + ty1) / 2, ty1 - 0.08):
        rod((-0.68, y, zb + 0.22), (-0.3, y, zb + 0.54), 0.009, M["canvas"])
        rod((-0.3, y, zb + 0.54), (0.3, y, zb + 0.36), 0.009, M["canvas"])
        rod((0.3, y, zb + 0.36), (0.68, y, zb + 0.22), 0.009, M["canvas"])

base = V.group(chassis)
modules = {"bed": V.group(bed)}
V.finish(mud=0.6, mud_top=0.45)
rig = V.light(3, 1.2)
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, light_rig=rig)
print("hauler:", N, "directions to", out)
