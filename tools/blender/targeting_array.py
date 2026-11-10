"""The targeting array (3x3, on a space platform; DESIGN.md "Orbital cannons"): a lattice dish on a squat base, pointed
down past the deck's edge at the planet, and at its heart Kessler-Hayashi's salvaged orbital beacon in a cage, glowing
the faction's cyan (the fight with Kessler-Hayashi is what opened it). The player's colours round it. 8 frames: the
beacon's pulse.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/targeting_array.py -- <out_dir>
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/player/targeting-array
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
FRAMES, TILES, MARGIN = int(os.environ.get("LP_FRAMES", 8)), 3, 2.4
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
P = lpkit.palette_worn()
CYAN = (0.45, 0.85, 1.0)
B = lpkit.box
core = lpkit.mat("core", (0.4, 0.8, 1.0), emit=CYAN, strength=2.0, grime=0.0)

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

def body():
    # The base: a low block on feet, a hazard band, a cable run.
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        B(0.36, 0.36, 0.1, sx * 1.1, sy * 1.1, 0, P["dark"])
    B(2.0, 2.0, 0.45, 0, 0, 0.1, P["paint"])
    B(2.04, 2.04, 0.06, 0, 0, 0.55, P["hazard"])
    B(0.9, 0.5, 0.3, 0.45, 0.65, 0.61, P["dark"])                               # its electronics, north-east
    for k in range(4):
        B(0.12, 0.04, 0.05, 0.15 + k * 0.2, 0.39, 0.75, P["glow"])
    # The yoke and the dish, tilted down to the south.
    lpkit.cyl(0.45, 0.25, 0, 0, 0.61, P["steel"], verts=32)
    for sx in (-0.42, 0.42):
        B(0.1, 0.3, 0.9, sx, 0, 0.86, P["steel"])
    # (Its bowl faces up and a little south: face on to the camera it read as a wheel, the first render.)
    tilt = math.radians(45)
    axle = (0, 0, 1.25)
    n = (0, -math.sin(tilt), math.cos(tilt))
    rot = (tilt, 0, 0)     # (about x by +tilt its axis leans south, to the camera: -tilt leaned it away, edge on)
    c = tuple(axle[i] + n[i] * 0.2 for i in range(3))
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=0.3, radius2=1.3, depth=0.65, end_fill_type="NOTHING",
                                    location=c, rotation=rot)
    d = bpy.context.object
    md = d.modifiers.new("s", "SOLIDIFY"); md.thickness = 0.05
    d.data.materials.append(P["steel"])
    bpy.ops.mesh.primitive_torus_add(major_radius=1.3, minor_radius=0.05, location=tuple(axle[i] + n[i] * 0.45 for i in range(3)),
                                     rotation=rot)
    bpy.context.object.data.materials.append(P["hazard"])
    # The salvaged beacon at its focus: a cage of four rods round a glowing core.
    focus = tuple(axle[i] + n[i] * 1.25 for i in range(3))
    rc = tuple(axle[i] + n[i] * 0.45 for i in range(3))
    u, v = (1, 0, 0), (0, n[2], -n[1])
    for ang in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        rim = tuple(rc[i] + 1.15 * (math.cos(ang) * u[i] + math.sin(ang) * v[i]) for i in range(3))
        lpkit.rod(rim, focus, 0.025, P["steel"])
    lpkit.sphere(0.2, *focus, core)
    for k in range(3):
        a = k * 2 * math.pi / 3
        lpkit.rod((focus[0] + math.cos(a) * 0.26, focus[1] + math.sin(a) * 0.26, focus[2] - 0.2),
                  (focus[0] + math.cos(a) * 0.26, focus[1] + math.sin(a) * 0.26, focus[2] + 0.2), 0.02, P["dark"])

model = group(body)
def set_frame(f):
    t = f / FRAMES
    lpkit.emission(core, 1.6 + 1.4 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)))
    lpkit.emission(P["glow"], 1.2 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + 1)))
    bpy.context.view_layer.update()
lpkit.bevel_all(model)
ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
lpkit.passes(scene, out, FRAMES, set_frame, model, {core, P["glow"]}, ground, sun, world)
print("rendered targeting array", out)
