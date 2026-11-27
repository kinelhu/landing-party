"""The player's buildings that turn or work (the user, 2026-11-10: "I still see some gross recolors. Why not use blender
again?"), each the whole sprite a frame (lpkit.passes, sheet.py), one a run:
  command-relay  3x3, a lattice mast, its antenna head turning: 32 steps (a radar's sprite turns whole)
  strip-drill    3x3, Grubstake's heavy drill frame, its drill head turning: 16 frames a direction, four directions
  flak-turret    2x2, a base (once) and its head in 64 directions (the turret turns the head toward its target)

    Blender -b -P tools/blender/turning_buildings.py -- <out dir> <name>
    then: uv run --with pillow python tools/blender/sheet.py <out dir>/<part> landing-party-graphics/graphics/player/<name>/<part>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
out, name = args[0], args[1]
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 48))
lpkit.gpu(scene)
V = mathutils.Vector
B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere


def M(n, rgb, metal=0.5, rough=0.5, emit=None, strength=0.0):
    return lpkit.mat(n, rgb, metal=metal, rough=rough, emit=emit, strength=strength, grime=0.4)


STEEL = M("steel", (0.3, 0.31, 0.33), 0.8, 0.4)
DARK = M("dark", (0.06, 0.065, 0.07), 0.6, 0.55)
PAINT = M("paint", (0.18, 0.26, 0.2), 0.3, 0.6)
OCHRE = lpkit.mat("ochre", (0.36, 0.22, 0.05), metal=0.3, rough=0.65, grime=0.8)
RUST = M("rust", (0.25, 0.11, 0.05), 0.5, 0.7)
HAZ = M("haz", (0.7, 0.55, 0.1), 0.2, 0.6)
CONCRETE = M("concrete", (0.2, 0.2, 0.19), 0.0, 0.85)
RUBBER = M("rubber", (0.03, 0.03, 0.03), 0.0, 0.85)
COPPER = M("copper", (0.5, 0.26, 0.12), 0.9, 0.4)
if os.path.isdir(lptex.TEX):
    STEEL = lptex.textured("steel-t", "Metal038", val=0.7, scale=2.0, edge=(0.5, 0.5, 0.5), dirt=0.7, rough_add=0.1)
    DARK = lptex.textured("dark-t", "Metal038", val=0.3, scale=2.0, edge=(0.3, 0.3, 0.29), dirt=0.6, rough_add=0.25)
    PAINT = lptex.textured("paint-t", "PaintedMetal006", hue=0.45, sat=0.5, val=0.55, scale=1.5, edge=(0.45, 0.45, 0.42))
    # (Ochre stays lpkit's grimed paint: a CC0 paint's hue turned, its rust turned with it, purple; from the red paint
    # it read as pale wood, the first renders.)
    RUST = lptex.textured("rust-t", "MetalPlates013", val=0.55, scale=1.2, edge=(0.4, 0.33, 0.25))
    HAZ = lptex.textured("haz-t", "PaintedMetal004", hue=0.66, sat=0.55, val=0.62, scale=1.5, edge=(0.42, 0.41, 0.38), rough_add=0.2)
CYAN = M("cyan", (0.2, 0.5, 0.6), 0.2, 0.3, emit=(0.45, 0.85, 1.0), strength=2.0)
AMBER = M("amber", (0.6, 0.4, 0.05), 0.1, 0.3, emit=(1.0, 0.65, 0.15), strength=2.0)


def bevel(o, w=0.03, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"; return o


def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]


def pivot(at):
    p = bpy.data.objects.new("pivot", None); scene.collection.objects.link(p); p.location = at; return p


def parent(objs, p):
    for o in objs:
        if o.parent is None and o is not p:
            m = o.matrix_world.copy(); o.parent = p; o.matrix_world = m


# --- The command relay ---------------------------------------------------------------------------------------------
def relay():
    def base():
        bevel(B(2.7, 2.7, 0.18, 0, 0, 0, CONCRETE), 0.05)
        for sx in (-1, 1):
            for sy in (-1, 1):
                rod((sx * 0.9, sy * 0.9, 0.18), (sx * 0.22, sy * 0.22, 3.0), 0.06, STEEL, verts=8)
                cyl(0.14, 0.12, sx * 0.9, sy * 0.9, 0.18, DARK, verts=12)
        for z in (0.8, 1.5, 2.2):
            k = 1 - (z - 0.18) / 2.82
            r = 0.22 + 0.68 * k
            for a, b in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
                rod((a[0] * r, a[1] * r, z), (b[0] * r, b[1] * r, z), 0.025, STEEL, verts=6)
        bevel(B(0.9, 0.6, 0.7, -0.75, 0.75, 0.18, PAINT), 0.04)
        bevel(B(0.6, 0.5, 0.5, 0.85, 0.8, 0.18, PAINT), 0.04)
        for k in range(3):
            B(0.08, 0.02, 0.04, -0.95 + k * 0.15, 0.44, 0.6, CYAN, bevel=0.0)
        B(0.3, 0.02, 0.08, 0.85, 0.54, 0.5, HAZ, bevel=0.0)
        rod((-0.75, 0.75, 0.88), (-0.2, 0.2, 2.8), 0.03, RUBBER, verts=6)
        cyl(0.3, 0.12, 0, 0, 3.0, DARK, verts=24)
    def head():
        cyl(0.24, 0.2, 0, 0, 3.12, PAINT, verts=24)
        B(1.6, 0.14, 0.1, 0, 0, 3.3, STEEL, bevel=0.02)
        for sx in (-1, 1):
            bevel(B(0.08, 0.5, 0.7, sx * 0.78, 0, 3.05, DARK), 0.02)
            for k in range(4):
                B(0.09, 0.42, 0.03, sx * 0.78, 0, 3.15 + k * 0.15, STEEL, bevel=0.0)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(0, -0.12, 3.55), segments=32, ring_count=16)
        o = bpy.context.object; o.scale = (1, 0.35, 1); o.data.materials.append(STEEL)
        rod((0, -0.1, 3.4), (0, -0.35, 3.55), 0.02, DARK, verts=6)
        sph(0.05, 0, 0, 3.95, AMBER); rod((0, 0, 3.4), (0, 0, 3.92), 0.015, STEEL, verts=6)
    b = group(base); h = group(head)
    p = pivot((0, 0, 0)); parent(h, p)
    return b + h + [p], p


# --- The strip drill -----------------------------------------------------------------------------------------------
def drill():
    def frame():
        # An open gantry: four legs, beams round the top, the motor on a cross-girder, so the turning head shows.
        bevel(B(2.8, 2.8, 0.22, 0, 0, 0, RUST), 0.05)
        # (Steel girders: its legs and beams in ochre paint read as wood, "is that supposed to be wood?", the user's
        # rating, 2026-11-10. Now I-section legs, dark, flanged in steel, a hazard band at each foot; the top beams steel
        # with riveted gussets, hazard chevrons along the front one.)
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * 1.15, sy * 1.15
                B(0.14, 0.36, 1.7, x, y, 0.22, DARK, bevel=0.01)                       # the web
                for fx in (-1, 1):
                    B(0.38, 0.05, 1.7, x, y + fx * 0.17, 0.22, STEEL, bevel=0.008)     # the flanges
                for z in (0.3, 0.42):
                    B(0.4, 0.4, 0.07, x, y, z, HAZ if z == 0.3 else DARK, bevel=0.0)
                B(0.5, 0.5, 0.1, x, y, 0.22, DARK, bevel=0.01)
                for k in range(2):
                    B(0.42, 0.42, 0.04, x, y, 0.9 + k * 0.6, DARK, bevel=0.0)          # rivet bands
        for sy in (-1, 1):
            bevel(B(2.7, 0.3, 0.28, 0, sy * 1.15, 1.92, STEEL), 0.02)
            bevel(B(0.3, 2.7, 0.28, sy * 1.15, 0, 1.92, STEEL), 0.02)
            for k in range(5):
                B(0.04, 0.32, 0.3, -1.0 + k * 0.5, sy * 1.15, 1.91, DARK, bevel=0.0)  # riveted gussets
        for k in range(9):
            B(0.26, 0.05, 0.24, -1.05 + k * 0.26, -1.31, 1.94, HAZ if k % 2 == 0 else DARK, bevel=0.0)
        bevel(B(2.4, 0.5, 0.3, 0, 0.2, 2.05, DARK), 0.03)
        bevel(B(0.9, 0.8, 0.7, 0, 0.2, 2.35, RUST), 0.05)
        cyl(0.22, 0.4, 0.5, 0.35, 2.35, STEEL, verts=16)
        cyl(0.12, 0.55, 0, 0.05, 1.5, STEEL, verts=12)
        for sx in (-1, 1):
            rod((sx * 1.15, -1.15, 0.6), (sx * 1.15, 1.15, 0.6), 0.035, STEEL, verts=6)
        # The chute at the front (north: the game puts its ore 1.85 tiles out that way), its rollers.
        bevel(B(0.7, 0.9, 0.3, 0, -1.55, 0.3, DARK), 0.03)
        for k in range(4):
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.06, depth=0.6, location=(0, -1.2 - k * 0.2, 0.62), rotation=(0, math.pi / 2, 0))
            bpy.context.object.data.materials.append(STEEL)
        B(0.5, 0.05, 0.12, 0.8, -1.3, 2.0, HAZ, bevel=0.0)
        rod((-1.15, 1.15, 1.92), (-0.4, 0.4, 2.4), 0.05, COPPER, verts=8)
        rod((1.15, 1.15, 1.92), (0.4, 0.5, 2.5), 0.04, RUBBER, verts=8)
    def bit():
        # The drill head: a fluted bit and its gear ring, seen through the frame's opening.
        cyl(0.62, 0.12, 0, 0, 1.5, DARK, verts=32)
        for k in range(16):
            a = k * 2 * math.pi / 16
            B(0.1, 0.16, 0.14, math.cos(a) * 0.62, math.sin(a) * 0.62, 1.48, STEEL, rot=a, bevel=0.005)
        for k in range(3):
            a = k * 2 * math.pi / 3
            rod((math.cos(a) * 0.15, math.sin(a) * 0.15, 1.5), (math.cos(a + 1.2) * 0.5, math.sin(a + 1.2) * 0.5, 0.3), 0.08, STEEL, verts=8)
        cyl(0.18, 1.3, 0, 0, 0.25, DARK, verts=16)
    f = group(frame); b = group(bit)
    p = pivot((0, 0, 0)); parent(b, p)
    return f + b + [p], p


# --- The flak turret -----------------------------------------------------------------------------------------------
def flak():
    def base():
        bevel(B(1.9, 1.9, 0.3, 0, 0, 0, RUST), 0.06)
        cyl(0.82, 0.3, 0, 0, 0.3, DARK, verts=40, bevel=0.04)
        lpkit.torus(0.8, 0.05, 0, 0, 0.6, HAZ)
        for sx, sy in ((-1, -1), (1, 1)):
            bevel(B(0.36, 0.26, 0.24, sx * 0.72, sy * 0.72, 0.3, OCHRE), 0.02)
            B(0.3, 0.02, 0.05, sx * 0.72, sy * 0.72 - 0.13, 0.42, HAZ, bevel=0.0)
    def head():
        cyl(0.62, 0.22, 0, 0, 0.6, OCHRE, verts=32, bevel=0.03)
        bevel(B(0.9, 0.8, 0.45, 0, 0.1, 0.82, OCHRE), 0.06)
        bevel(B(0.7, 0.3, 0.3, 0, 0.35, 1.27, DARK), 0.03)
        # Twin stubby flak barrels pointing north (the game turns the head), muzzle brakes, a ranging dish.
        for sx in (-1, 1):
            rod((sx * 0.22, -0.2, 1.05), (sx * 0.22, -1.05, 1.35), 0.09, STEEL, verts=14)
            cyl(0.13, 0.18, sx * 0.22, -1.08, 1.27, DARK, verts=14, rot=(math.radians(70), 0, 0))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2, location=(0.42, 0.3, 1.45), segments=24, ring_count=12)
        o = bpy.context.object; o.scale = (1, 0.3, 1); o.rotation_euler = (math.radians(-30), 0, 0); o.data.materials.append(STEEL)
        B(0.3, 0.3, 0.2, -0.35, 0.35, 1.27, RUST, bevel=0.02)
        sph(0.04, -0.35, 0.5, 1.5, AMBER)
    b = group(base); h = group(head)
    p = pivot((0, 0, 0)); parent(h, p)
    return b, h, p


FILL = 0.38
if name == "command-relay":
    model, p = relay()
    ground, sun, world = lpkit.stage(scene, 3, 3.2)
    sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
    N = int(os.environ.get("LP_FRAMES", 32))
    def set_frame(f): p.rotation_euler = (0, 0, f * 2 * math.pi / N); bpy.context.view_layer.update()
    lpkit.passes(scene, f"{out}/command-relay", N, set_frame, model, {CYAN, AMBER}, ground, sun, world, shadow_each=True, fill=FILL)
elif name == "strip-drill":
    model, p = drill()
    rig = bpy.data.objects.new("rig", None); scene.collection.objects.link(rig)
    for o in model:
        if o.parent is None: o.parent = rig
    ground, sun, world = lpkit.stage(scene, 3, 1.4)
    sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
    N = int(os.environ.get("LP_FRAMES", 16))
    for d, yaw in (("north", 0), ("east", 270), ("south", 180), ("west", 90)):
        rig.rotation_euler = (0, 0, math.radians(yaw)); bpy.context.view_layer.update()
        def set_frame(f): p.rotation_euler = (0, 0, f * 2 * math.pi / N / 3); bpy.context.view_layer.update()
        lpkit.passes(scene, f"{out}/strip-drill-{d}", N, set_frame, model, {CYAN, AMBER}, ground, sun, world, fill=FILL)
elif name == "flak-turret":
    base, head, p = flak()
    ground, sun, world = lpkit.stage(scene, 2, 1.4)
    sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
    # (Each part's pass without the other's shadow: hidden from the camera alone, the head cast its shadow into the base's
    # and the base its own again into each of the head's, faction_works.py's turrets, 2026-11-10.)
    for o in head: o.visible_camera = False; o.visible_shadow = False
    lpkit.passes(scene, f"{out}/flak-base", 1, lambda f: None, base, {AMBER}, ground, sun, world, fill=FILL)
    for o in head: o.visible_camera = True; o.visible_shadow = True
    for o in base: o.visible_camera = False; o.visible_shadow = False
    N = int(os.environ.get("LP_FRAMES", 64))
    # (Clockwise from north, as the game counts a rotated sprite's directions. Its barrels are modelled to the south:
    # half a turn on, or its first frame aimed south and it fired backwards, 2026-11-10.)
    def set_frame(f): p.rotation_euler = (0, 0, math.pi - f * 2 * math.pi / N); bpy.context.view_layer.update()
    lpkit.passes(scene, f"{out}/flak-head", N, set_frame, head, {AMBER}, ground, sun, world, shadow_each=True, fill=FILL)
print("rendered", name)
