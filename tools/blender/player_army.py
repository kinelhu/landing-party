"""The player's army buildings, modelled and rendered in olive drab (apart from Kessler-Hayashi's slate and Grubstake's
amber; the user, 2026-11-03: barracks a prime candidate, the muster point a steel chest):
  barracks  3x3: a hangar block, a slatted door to the south, an annex, sandbags, lit windows, a flagpole, a rooftop dish
            turning and a beacon blinking (16 frames: its working animation).
  muster    1x1: a rally post, a flag, a lamp box, a sign (one frame).

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/player_army.py -- <barracks|muster> <out_dir>
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/player/<name>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
WHAT, out = args[0], args[1]
scene = lpkit.reset(); scene.cycles.samples = 64
P = lpkit.palette_worn()
P["paint"] = lpkit.worn("olive", (0.25, 0.27, 0.18), metal=0.2, rough=0.65, seams=5)
P["window"] = lpkit.mat("window", (0.1, 0.1, 0.08), emit=(1.0, 0.8, 0.45), strength=1.2, grime=0.0)
P["beacon"] = lpkit.mat("beacon", (0.3, 0.05, 0.05), emit=(1.0, 0.15, 0.1), strength=0.0, grime=0.0)
P["cloth"] = lpkit.mat("cloth", (0.45, 0.12, 0.08), metal=0.0, rough=0.9, grime=0.3)
sand = lpkit.worn("sand", (0.36, 0.31, 0.22), metal=0.0, rough=0.9, seams=12, rivets=False, wear=0.2)
B = lpkit.box

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

if WHAT == "barracks":
    FRAMES, TILES, MARGIN = 16, 3, 2.2
    dish = []
    def build():
        B(2.9, 2.9, 0.08, 0, 0, 0, P["dark"])                            # pad
        B(2.3, 1.7, 0.85, 0, 0.15, 0.08, P["paint"])                    # hangar block
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.15, 0.93 + 0.18))   # pitched roof
        r = bpy.context.object
        for v in r.data.vertices:
            if v.co.z > 0: v.co.x *= 0.15
        r.scale = (2.4, 1.8, 0.36); r.data.materials.append(P["steel"])
        B(1.2, 0.06, 0.62, 0, -0.72, 0.08, P["dark"])                    # the door
        for k in range(6):
            B(1.18, 0.07, 0.025, 0, -0.73, 0.14 + k * 0.1, P["steel"])   # its slats
        B(1.3, 0.1, 0.06, 0, -0.74, 0.72, P["hazard"])                   # its lintel, worn yellow
        for x in (-0.85, 0.85):
            B(0.3, 0.05, 0.16, x, -0.72, 0.5, P["window"])               # lit windows
        B(0.7, 1.1, 0.6, -1.25, 0.25, 0.08, P["paint"])                  # annex
        B(0.74, 1.14, 0.05, -1.25, 0.25, 0.68, P["steel"])
        for k in range(5):                                               # sandbags either side of the door
            for x in (-0.85, 0.85):
                bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=12, ring_count=8, location=(x + (k - 2) * 0.12 * (1 if x > 0 else -1), -1.0, 0.13 + (k % 2) * 0.1))
                o = bpy.context.object; o.scale = (0.12, 0.08, 0.06); o.data.materials.append(sand)
        lpkit.rod((1.25, -0.95, 0.08), (1.25, -0.95, 1.6), 0.02, P["steel"])   # flagpole
        B(0.02, 0.36, 0.22, 1.25, -0.77, 1.35, P["cloth"])                     # flag
        lpkit.cyl(0.08, 0.35, 0.6, 0.4, 1.2, P["steel"], verts=12)            # rooftop mast
        lpkit.sphere(0.05, 0.6, 0.4, 1.6, P["beacon"])                         # beacon
        lpkit.cyl(0.04, 0.12, -0.5, 0.5, 1.2, P["steel"], verts=10)           # dish post
    def build_dish():
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.24, radius2=0.04, depth=0.09, end_fill_type="NOTHING",
                                        location=(0, 0.04, 0), rotation=(math.radians(125), 0, 0))
        d = bpy.context.object; d.modifiers.new("s", "SOLIDIFY").thickness = 0.02; d.data.materials.append(P["steel"])
    model = group(build)
    dish = group(build_dish)
    bpy.ops.object.empty_add(location=(-0.5, 0.5, 1.38)); piv = bpy.context.object
    for o in dish:
        o.parent = piv; o.location = (0, 0, 0)
    def set_frame(f):
        piv.rotation_euler = (0, 0, -2 * math.pi * f / FRAMES)
        lpkit.emission(P["beacon"], 4.0 if f % 8 < 2 else 0.0)
        bpy.context.view_layer.update()
    allm = model + dish
    lpkit.bevel_all(allm)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, allm, {P["window"], P["beacon"]}, ground, sun, world)
else:
    FRAMES, TILES, MARGIN = 1, 1, 1.6
    def build():
        B(0.8, 0.8, 0.06, 0, 0, 0, P["dark"])
        B(0.36, 0.3, 0.32, 0, 0.05, 0.06, P["paint"])                    # lamp box
        B(0.3, 0.02, 0.1, 0, -0.11, 0.25, P["window"])                   # its lit face
        lpkit.rod((0.22, -0.18, 0.06), (0.22, -0.18, 1.25), 0.018, P["steel"])   # post
        B(0.02, 0.3, 0.18, 0.22, -0.02, 1.05, P["cloth"])                # flag
        B(0.28, 0.03, 0.16, -0.12, -0.25, 0.38, P["hazard"])             # sign
        lpkit.rod((-0.12, -0.25, 0.06), (-0.12, -0.25, 0.32), 0.012, P["steel"])
    model = group(build)
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, lambda f: None, model, {P["window"]}, ground, sun, world)
print("rendered", WHAT, out)
