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
# (The corporations' palette of their clay-first buildings: these two, on the bright worn palette, rated 2, "bit too toy
# like", the user, 2026-11-10.)
P = lpkit.palette_faction(CORP)
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
        # A railing round the housing's roof, a ladder up its east side, a cable run to the power box, conduit.
        for (x0, y0), (x1, y1) in (((-0.8, -0.8), (0.8, -0.8)), ((0.8, -0.8), (0.8, 0.5)), ((-0.8, 0.5), (-0.8, -0.8))):
            lpkit.rod((x0, y0, 0.95), (x1, y1, 0.95), 0.012, P["hazard"])
            for t in (0.0, 0.5, 1.0):
                lpkit.rod((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.7), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.95), 0.01, P["steel"])
        for k in range(5):
            lpkit.rod((0.82, -0.5 + 0.0, 0.12 + k * 0.12), (0.82, -0.3, 0.12 + k * 0.12), 0.01, P["steel"])
        lpkit.rod((0.82, -0.5, 0.1), (0.82, -0.5, 0.7), 0.012, P["steel"]); lpkit.rod((0.82, -0.3, 0.1), (0.82, -0.3, 0.7), 0.012, P["steel"])
        lpkit.rod((0.7, 0.75, 0.2), (0.3, 0.5, 0.15), 0.035, P["rubber"])
        for x in (-0.55, -0.25):
            lpkit.rod((x, -0.81, 0.15), (x, -0.81, 0.62), 0.03, P["steel"])
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
        d.data.materials.append(P["paint"])
        # Ribs on its back, from the hub out to the rim (a plain cone read as a toy's dish).
        for k in range(8):
            ang = k * math.pi / 4
            u = (math.cos(ang), math.sin(ang) * -n[2], math.sin(ang) * n[1])
            p0 = tuple(c[i] - n[i] * 0.14 + u[i] * 0.14 for i in range(3)); p1 = tuple(c[i] + n[i] * 0.12 + u[i] * 0.8 for i in range(3))
            lpkit.rod(p0, p1, 0.02, P["dark"])
        rim_c = tuple(c[i] + n[i] * 0.14 for i in range(3))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.82, minor_radius=0.03, location=rim_c, rotation=(math.radians(125), 0, 0))
        bpy.context.object.data.materials.append(P["dark"])
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
        lpkit.emission(P["glow"], 0.9 + 0.5 * math.sin(f / FRAMES * 8 * math.pi))
        bpy.context.view_layer.update()
    still_objs += lpkit.scatter(still_objs, {P["paint"]}, P["dark"], P["steel"], seed=3, density=4.0)
    model = still_objs + turn_objs
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, model, {P["glow"]}, ground, sun, world, shadow_each=True)
else:
    FRAMES, TILES, MARGIN = 32, 4, 2.6
    rings = []
    def build():
        # A dark plinth, a smaller equipment core on it, four cabinets round it on the plinth's corners; an open lattice
        # spire (four legs tapering, braced) over the core, guyed; three emitter collars, dark steel, each with a thin lit
        # band the pulse climbs; a crown. (Its first, a solid cone ringed in white on a flat box, "too toy like".)
        B(2.0, 2.0, 0.18, 0, 0, 0.0, P["dark"], bevel=0.03)
        B(1.15, 1.15, 0.55, 0, 0, 0.18, P["paint"])
        B(1.2, 1.2, 0.05, 0, 0, 0.73, P["trim"])
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            cx, cy = math.cos(a) * 0.98, math.sin(a) * 0.98
            B(0.42, 0.34, 0.42, cx * 0.92, cy * 0.92, 0.18, P["paint"] if k % 2 else P["trim"], rot=a)
            B(0.3, 0.03, 0.08, cx * 0.92 - math.sin(a) * 0.0, cy * 0.92, 0.42, P["hazard"], rot=a)
            lpkit.rod((cx * 0.7, cy * 0.7, 0.3), (cx * 0.45, cy * 0.45, 0.3), 0.03, P["rubber"])
            c, sn = math.cos(a), math.sin(a)
            lpkit.rod((c * 1.35, sn * 1.35, 0.05), (c * 0.2, sn * 0.2, 3.3), 0.012, P["steel"])   # guy lines
            B(0.16, 0.16, 0.1, c * 1.37, sn * 1.37, 0.0, P["dark"])
        for k in range(4):
            a = k * math.pi / 2
            B(0.4, 0.05, 0.22, math.cos(a) * 0.58, math.sin(a) * 0.58, 0.3, P["dark"], rot=a + math.pi / 2)
        H0, H1 = 0.78, 3.7
        def leg(i, z):
            w = 0.42 - 0.3 * (z - H0) / (H1 - H0)
            a = i * math.pi / 2 + math.pi / 4
            return (math.cos(a) * w, math.sin(a) * w, z)
        for i in range(4):
            lpkit.rod(leg(i, H0), leg(i, H1), 0.035, P["steel"])
        z = H0
        while z < H1 - 0.35:
            for i in range(4):
                j = (i + 1) % 4
                lpkit.rod(leg(i, z), leg(j, z + 0.45), 0.013, P["steel"])
                lpkit.rod(leg(i, z), leg(j, z), 0.016, P["dark"])
            z += 0.45
        lpkit.rod((0.1, -0.1, H0), (0.04, -0.04, H1), 0.03, P["rubber"])            # the feed up the core
        for i, zz in enumerate((1.5, 2.3, 3.0)):
            w = leg(0, zz)[0] / math.cos(math.pi / 4) + 0.08
            lpkit.torus(w, 0.05, 0, 0, zz, P["dark"])
            m = lpkit.mat(f"ring{i}", (0.06, 0.08, 0.09), metal=0.5, rough=0.4,
                          emit=(0.25, 0.7, 1.0) if CORP == "serenity" else (1.0, 0.55, 0.12), strength=0.0)
            rings.append(m)
            lpkit.torus(w, 0.022, 0, 0, zz + 0.06, m)
        lpkit.cyl(0.16, 0.12, 0, 0, H1, P["trim"], verts=12)
        lpkit.rod((0, 0, H1 + 0.12), (0, 0, H1 + 0.5), 0.025, P["steel"])
        lpkit.sphere(0.07, 0, 0, H1 + 0.55, P["glow"])
    model = group(build)
    def set_frame(f):
        t = f / FRAMES
        for i, m in enumerate(rings):
            d = abs(((t * 3 - i) + 1.5) % 3 - 1.5)
            lpkit.emission(m, max(0.0, 1.8 - 1.7 * d))
        lpkit.emission(P["glow"], 0.9 + 0.5 * math.sin(t * 2 * math.pi))
    model += lpkit.scatter(model, {P["paint"], P["trim"]}, P["dark"], P["steel"], seed=5, density=4.0)
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, model, set(rings) | {P["glow"]}, ground, sun, world)
print("rendered", WHAT, CORP, out)
