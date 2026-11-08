"""Grubstake's bomb drone (id lp-scavenger, its Wheels node: it bursts on what it dives on and dies; the unit pass,
2026-11-08, after the harrier): a scrap quadcopter carrying its bomb. An X of tubes with four rotors (blurred discs, as
the harrier's: they read as turning hovering or not), a battery box and a radio on its back, the bomb slung under it:
a red gas cylinder, tail fins welded on, a bright detonator at its nose, a bundle of dynamite strapped alongside; the
red pennant. It hovers a tile up (the defender's height), its shadow on the ground. Layers: the frame and the bomb
(base), the rotors (their own), the shadow of both.

    /Applications/Blender.app/Contents/MacOS/Blender -b [-t 4] -P tools/blender/scavenger.py -- <out_dir> [N=64]
    then one sheet.py run a part: out/base, out/rotor
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

H = 0.95                               # its height above the ground (the defender's)
# (Four bright rings over a hidden bomb, the first: the rotors smaller and further out, their rims faint, the bomb bigger.)
ARM, RR = 0.42, 0.15                   # an arm's reach from the middle, a rotor's radius

def frame():
    # The X of arms, thick tubes in amber, a motor pod at each end; a deck plate at the middle.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        x, y = math.cos(a) * ARM, math.sin(a) * ARM
        rod((0, 0, H), (x, y, H + 0.02), 0.026, M["cage"])
        cyl(0.045, 0.07, x, y, H - 0.02, M["plate"], bevel=0.008)
        cyl(0.02, 0.03, x, y, H + 0.05, M["steel"])
        rod((x, y, H - 0.02), (x * 1.05, y * 1.05, H - 0.16), 0.01, M["tube"])                  # a leg under each pod
    box(0.24, 0.24, 0.04, 0, 0, H - 0.02, M["amber"], bevel=0.012)
    # Its back: a battery box, a radio with a short whip, the red pennant on it; wires to the motors.
    box(0.13, 0.11, 0.07, -0.02, -0.02, H + 0.02, M["dark"], bevel=0.01)
    box(0.06, 0.08, 0.05, 0.07, 0.04, H + 0.02, M["olive"], bevel=0.008)
    rod((0.08, 0.05, H + 0.07), (0.06, -0.02, H + 0.42), 0.006, M["bright"])
    V.panel([(0.065, 0.0, H + 0.3), (0.06, -0.02, H + 0.42), (0.06, -0.18, H + 0.36)], M["rag"], t=0.004)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rod((-0.02, -0.02, H + 0.05), (math.cos(a) * ARM * 0.7, math.sin(a) * ARM * 0.7, H + 0.03), 0.005, M["rubber"])
    # The bomb under it: a red gas cylinder on two straps, domed ends, its fins at the tail, the detonator at its nose
    # (forward, +y), a bundle of dynamite strapped alongside, a lamp at the nose to read it by.
    BZ = H - 0.24
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.1, depth=0.5, location=(0, 0, BZ), rotation=(math.pi / 2, 0, 0))
    V.obj().data.materials.append(M["red"])
    for sy in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.1, location=(0, sy * 0.25, BZ), segments=32, ring_count=16)
        o = V.obj(); o.scale = (1, 0.5, 1); o.data.materials.append(M["red"])
    for y in (-0.1, 0.1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.102, minor_radius=0.01, location=(0, y, BZ), rotation=(math.pi / 2, 0, 0),
                                         major_segments=32, minor_segments=6)
        V.obj().data.materials.append(M["dark"])
        rod((-0.07, y, BZ + 0.05), (-0.06, y, H - 0.02), 0.008, M["dark"])
        rod((0.07, y, BZ + 0.05), (0.06, y, H - 0.02), 0.008, M["dark"])
    box(0.07, 0.22, 0.07, 0, 0.0, BZ + 0.07, M["yellow"], bevel=0.006)                               # a hazard band
    for k in range(4):                                                                               # fins
        a = k * math.pi / 2
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 0.1, -0.3, BZ + math.sin(a) * 0.1), rotation=(0, -a, 0))
        o = V.obj(); o.scale = (0.1, 0.1, 0.008); o.data.materials.append(M["steel"])
    rod((0, 0.3, BZ), (0, 0.38, BZ), 0.024, M["bright"])                                             # detonator
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.03, location=(0, 0.39, BZ), segments=16, ring_count=8)
    V.obj().data.materials.append(M["bright"])
    cyl(0.016, 0.005, 0, 0.415, BZ, M["tail"], rot=(math.pi / 2, 0, 0))                              # its arming lamp
    for k in range(4):                                                                               # dynamite
        x, z = 0.125 + (k % 2) * 0.03, BZ - 0.02 + (k // 2) * 0.03
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.016, depth=0.2, location=(x, 0.02, z), rotation=(math.pi / 2, 0, 0))
        V.obj().data.materials.append(M["red"])
    for y in (-0.05, 0.09):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.032, minor_radius=0.005, location=(0.115, y, BZ - 0.005), rotation=(math.pi / 2, 0, 0),
                                         major_segments=24, minor_segments=6)
        V.obj().data.materials.append(M["canvas"])
    rod((0.13, 0.1, BZ), (0.0, 0.24, BZ + 0.02), 0.004, M["dark"])                                  # its fuse to the nose

def rotors():
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        x, y = math.cos(a) * ARM, math.sin(a) * ARM
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=RR, depth=0.004, location=(x, y, H + 0.065))
        V.obj().data.materials.append(V.blur_mat("rotor%d" % k, (0.12, 0.12, 0.11), 0.16, streaks=2.0))
        bpy.ops.mesh.primitive_torus_add(major_radius=RR, minor_radius=0.005, location=(x, y, H + 0.065), major_segments=64, minor_segments=6)
        V.obj().data.materials.append(V.blur_mat("rim%d" % k, (0.45, 0.44, 0.4), 0.1, streaks=0.0))
        cyl(0.018, 0.02, x, y, H + 0.06, M["steel"])

base = V.group(frame)
modules = {"rotor": V.group(rotors)}
V.finish(mud=0.0)
rig = V.light(2, 2.2)
_z = float(os.environ.get("LP_ZOOM", 1))
V.scene.camera.data.ortho_scale /= _z
V.passes(out, N, base, modules, light_rig=rig)
print("scavenger:", N, "directions to", out)
