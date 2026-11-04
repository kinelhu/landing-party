"""Two of the corporations' antennas, modelled and rendered for a radar's directions (its turning plays them):
  relay     Kessler-Hayashi's orbital relay (3x3): a tracking dish on a yoke over an equipment housing; 64 frames, the
            dish turning in azimuth (its shadow with it).
  pacifier  the pacifier (4x4, both corporations): a tapered broadcast spire, three emitter rings and a crown, a pulse
            climbing it; 32 frames.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/antennas.py -- <relay|pacifier> <out_dir> [serenity|grubstake]
    then: uv run --with pillow python tools/blender/sheet.py <out_dir> landing-party/graphics/<corp>/<name>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import lpkit

args = sys.argv[sys.argv.index("--") + 1:]
WHAT, out = args[0], args[1]
CORP = args[2] if len(args) > 2 else "serenity"
scene = lpkit.reset(); scene.cycles.samples = 64
P = lpkit.palette_worn()
if CORP == "grubstake":
    P["paint"] = lpkit.worn("paint_g", (0.4, 0.27, 0.13), metal=0.25, rough=0.65, seams=5)
B = lpkit.box

def group(fn):
    before = set(scene.objects); fn(); return [o for o in scene.objects if o not in before]

if WHAT == "relay":
    FRAMES, TILES, MARGIN = int(os.environ.get("LP_FRAMES", 64)), 3, 2.2
    def fixed():
        lpkit.feet(1.9, P["dark"])                                        # under the housing's corners
        B(1.6, 1.3, 0.55, 0, -0.15, 0.1, P["paint"])                     # equipment housing
        B(1.65, 1.35, 0.05, 0, -0.15, 0.65, P["steel"])
        for x in (-0.5, 0.0, 0.5):
            B(0.3, 0.04, 0.3, x, -0.82, 0.2, P["dark"])                  # vents
        B(0.35, 0.3, 0.25, 0.85, 0.75, 0.1, P["dark"]); B(0.36, 0.31, 0.03, 0.85, 0.75, 0.35, P["steel"])   # power box
        lpkit.cyl(0.32, 0.25, 0, 0.1, 0.7, P["steel"], verts=24)          # bearing
    def moving():
        lpkit.cyl(0.26, 0.12, 0, 0, 0.95, P["dark"], verts=24)           # turntable
        for sx in (-0.38, 0.38):
            B(0.07, 0.2, 0.6, sx, 0, 1.0, P["paint"])                    # yoke arms
        # The dish: an open shallow cone, its back on the elevation axle, facing north and up 35 degrees at frame 0. (A
        # sphere's cap floated above its yoke, the first render.) Its face: rotating the cone's open side (-z) by 125
        # degrees about x points it along (0, cos 35, sin 35).
        n = (0, math.cos(math.radians(35)), math.sin(math.radians(35)))
        axle = (0, 0.0, 1.55)
        c = tuple(axle[i] + n[i] * 0.16 for i in range(3))
        bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=0.82, radius2=0.12, depth=0.3, end_fill_type="NOTHING",
                                        location=c, rotation=(math.radians(125), 0, 0))
        d = bpy.context.object
        md = d.modifiers.new("s", "SOLIDIFY"); md.thickness = 0.035
        d.data.materials.append(P["steel"])
        focus = tuple(axle[i] + n[i] * 0.85 for i in range(3))
        for ang in (0, 2.1, 4.2):                                          # feed struts from the rim to the focus
            rim = (math.cos(ang) * 0.7, c[1] + n[2] * math.sin(ang) * -0.7 + n[1] * 0.16, c[2] + n[1] * math.sin(ang) * 0.7)
            lpkit.rod(rim, focus, 0.014, P["steel"])
        lpkit.sphere(0.06, *focus, P["glow"])                               # the feed horn, lit
        lpkit.box(0.3, 0.3, 0.22, 0, -0.32, 1.38, P["dark"])               # counterweight behind the axle
        lpkit.rod((-0.38, 0, 1.55), (0.38, 0, 1.55), 0.04, P["steel"])    # elevation axle
    still_objs = group(fixed)
    turn_objs = group(moving)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
    for o in turn_objs:
        o.parent = pivot; o.matrix_parent_inverse = pivot.matrix_world.inverted()
    def set_frame(f):
        pivot.rotation_euler = (0, 0, -2 * math.pi * f / FRAMES)
        lpkit.emission(P["glow"], 1.5 + 0.8 * math.sin(f / FRAMES * 8 * math.pi))
        bpy.context.view_layer.update()
    model = still_objs + turn_objs
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, model, {P["glow"]}, ground, sun, world, shadow_each=True)
else:
    FRAMES, TILES, MARGIN = 32, 4, 2.6
    rings = []
    def build():
        B(1.9, 1.9, 0.45, 0, 0, 0.1, P["paint"])
        B(1.95, 1.95, 0.05, 0, 0, 0.55, P["steel"])
        for k in range(4):
            a = k * math.pi / 2
            B(0.5, 0.05, 0.25, math.cos(a) * 0.97, math.sin(a) * 0.97, 0.18, P["dark"], rot=a + math.pi / 2)
            c, sn = math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)
            lpkit.rod((c * 1.2, sn * 1.2, 0.05), (c * 0.25, sn * 0.25, 3.2), 0.018, P["steel"])   # guy lines
            B(0.18, 0.18, 0.12, c * 1.22, sn * 1.22, 0.0, P["dark"])
        # The spire: tapered, four-sided, in two stages.
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.42, radius2=0.2, depth=2.2, location=(0, 0, 0.6 + 1.1), rotation=(0, 0, math.pi / 4))
        bpy.context.object.data.materials.append(P["paint"])
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.2, radius2=0.08, depth=1.2, location=(0, 0, 2.8 + 0.6), rotation=(0, 0, math.pi / 4))
        bpy.context.object.data.materials.append(P["steel"])
        for i, z in enumerate((1.4, 2.25, 3.0)):
            m = lpkit.mat(f"ring{i}", (0.3, 0.32, 0.34), metal=0.8, rough=0.4, emit=(0.6, 0.9, 1.0) if CORP == "serenity" else (1.0, 0.75, 0.4), strength=0.0)
            rings.append(m)
            lpkit.torus(0.42 - i * 0.1, 0.045, 0, 0, z, m)
        lpkit.sphere(0.12, 0, 0, 4.05, P["glow"])
    model = group(build)
    def set_frame(f):
        t = f / FRAMES
        for i, m in enumerate(rings):
            d = abs(((t * 3 - i) + 1.5) % 3 - 1.5)
            lpkit.emission(m, max(0.0, 2.5 - 2.4 * d))
        lpkit.emission(P["glow"], 1.4 + 0.9 * math.sin(t * 2 * math.pi))
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, model, set(rings) | {P["glow"]}, ground, sun, world)
print("rendered", WHAT, CORP, out)
