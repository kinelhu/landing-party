"""The player's orbital cannon (3x3, on a space platform; DESIGN.md "Orbital cannons"), in the style of the mod's rendered
buildings: a braced ring on four feet, a turret drum, a long twin-rail barrel angled down past the platform's edge (it
fires at the planet below), capacitor rings along the barrel lighting in turn as it charges, thruster fuel tanks and a
radiator bank behind. The player's colours (worn steel, hazard yellow) and the orbital cyan of the strike. 16 frames: the
charge climbing the rings (the machine's animation plays while it charges).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/orbital_cannon.py -- <out_dir>
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/player/orbital-cannon
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES, TILES, MARGIN = int(os.environ.get("LP_FRAMES", 16)), 3, 2.6
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
P = lpkit.palette_worn()
CYAN = (0.45, 0.85, 1.0)
B = lpkit.box

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

rings = []
def body():
    # Four feet and the braced ring: the mount on the deck.
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        B(0.42, 0.42, 0.12, sx * 1.15, sy * 1.15, 0, P["dark"])
        lpkit.rod((sx * 1.15, sy * 1.15, 0.12), (sx * 0.55, sy * 0.55, 0.55), 0.07, P["steel"])
    lpkit.cyl(1.3, 0.2, 0, 0, 0.45, P["dark"], verts=48)
    lpkit.cyl(1.25, 0.07, 0, 0, 0.65, P["hazard"], verts=48)
    # The drum.
    lpkit.cyl(0.95, 0.65, 0, 0.05, 0.72, P["paint"], verts=40)
    lpkit.cyl(0.98, 0.05, 0, 0.05, 1.37, P["steel"], verts=40)
    B(0.7, 0.7, 0.4, 0.15, 0.15, 1.42, P["dark"], rot=math.radians(45))           # breech housing
    # Thruster fuel tanks and their pipe, behind (north).
    for ox in (-0.62, 0.62):
        lpkit.cyl(0.22, 0.9, ox, 0.95, 0.12, P["hazard"], verts=20)
        lpkit.cyl(0.235, 0.05, ox, 0.95, 1.02, P["steel"], verts=20)
        lpkit.rod((ox, 0.95, 0.85), (ox * 0.4, 0.55, 1.2), 0.045, P["copper"])
    # Radiator fins, the east side.
    for k in range(6):
        B(0.05, 0.7, 0.55, 1.05 + k * 0.08 - 0.2, 0.3, 0.7, P["steel"], bevel=0.005)
    # The barrel: two rails from the breech, out to the south-west (its length seen from the camera, not end on), dipping
    # towards the planet past the deck's edge.
    d = (-math.cos(math.radians(40)), -math.sin(math.radians(40)))
    base = (0.0, 0.0, 1.7)
    L = 3.3
    tip = (base[0] + d[0] * L, base[1] + d[1] * L, base[2] - 0.55)
    side = (-d[1], d[0])
    for sx in (-0.16, 0.16):
        lpkit.rod((base[0] + side[0] * sx, base[1] + side[1] * sx, base[2]), (tip[0] + side[0] * sx, tip[1] + side[1] * sx, tip[2]),
                  0.07, P["steel"], verts=12)
    lpkit.rod(base, tip, 0.045, P["dark"], verts=10)
    yaw = math.atan2(d[1], d[0])
    pitch = math.atan2(base[2] - tip[2], L)
    # The capacitor rings along it, lit in turn as it charges.
    for i in range(5):
        t = 0.18 + i * 0.16
        c = tuple(base[k] + (tip[k] - base[k]) * t for k in range(3))
        m = lpkit.mat(f"cap{i}", (0.25, 0.27, 0.3), metal=0.8, rough=0.35, emit=CYAN, strength=0.0)
        rings.append(m)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.26, minor_radius=0.045, location=c,
                                         rotation=(0, math.pi / 2 + pitch, yaw))
        bpy.context.object.data.materials.append(m)
    # Its muzzle.
    lpkit.cyl(0.16, 0.18, tip[0], tip[1], tip[2] - 0.09, P["dark"], verts=16)
    lpkit.sphere(0.07, tip[0], tip[1] - 0.02, tip[2], P["glow"])
    # Small kit on the drum: hatches, a beacon light.
    B(0.2, 0.2, 0.08, -0.45, -0.2, 1.29, P["steel"]); B(0.16, 0.24, 0.06, 0.45, 0.35, 1.29, P["steel"])
    lpkit.sphere(0.06, -0.55, 0.55, 1.35, P["glow"])

model = group(body)
def set_frame(f):
    t = f / FRAMES
    for i, m in enumerate(rings):
        dd = abs(((t * len(rings) - i) + len(rings) / 2) % len(rings) - len(rings) / 2)
        lpkit.emission(m, max(0.05, 2.2 - 2.0 * dd))
    lpkit.emission(P["glow"], 1.4 + 0.9 * math.sin(t * 2 * math.pi))
    bpy.context.view_layer.update()
lpkit.bevel_all(model)
ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
lpkit.passes(scene, out, FRAMES, set_frame, model, set(rings) | {P["glow"]}, ground, sun, world)
print("rendered orbital cannon", out)
