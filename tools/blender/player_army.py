"""The player's army buildings, modelled and rendered in Factorio's warm steel (the olive drab hangar, 2026-11-03, read as
toy soldiers, the user, 2026-11-04):
  barracks  3x3: a training plant, an assembler's chamfered block, a roll-up bay door, roof fans turning, an amber lamp
            (16 frames: its working animation).
  muster    1x1: a post, a radio box, a whip antenna, a floodlight (one frame).

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
    # The training plant (the user, 2026-11-04, of the olive hangar: "the least convincing building. Can we imagine
    # something more factorio like? And less Army Men"): a machine in Factorio's own terms, an assembler's chamfered block
    # in warm steel, a roll-up bay door to the south its troopers walk out of, two roof fans, an exhaust stack, a lit
    # control window; training, its fans turn, the strip over its door runs and its amber lamp sweeps (16 frames).
    FRAMES, TILES, MARGIN = 16, 3, 2.2
    tan = lpkit.worn("tan", (0.34, 0.31, 0.26), metal=0.35, rough=0.55, seams=1.5, rivets=False)   # (seams 6 read as planks)
    rust = lpkit.worn("rust", (0.32, 0.17, 0.08), metal=0.2, rough=0.8, seams=8, rivets=False)
    P["strip"] = lpkit.mat("strip", (0.2, 0.15, 0.05), emit=(1.0, 0.65, 0.2), strength=0.0, grime=0.0)
    P["lamp"] = lpkit.mat("lamp", (0.4, 0.25, 0.05), emit=(1.0, 0.6, 0.1), strength=0.0, grime=0.0)
    fans = []
    def build():
        # The block: chamfered corners (an octagon prism), a skirt of dark steel at its foot, a steel cornice.
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.5, depth=0.95, location=(0, 0.05, 0.475),
                                            rotation=(0, 0, math.pi / 8))
        b = bpy.context.object; b.scale = (1.0, 0.92, 1.0); b.data.materials.append(tan)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.53, depth=0.16, location=(0, 0.05, 0.08),
                                            rotation=(0, 0, math.pi / 8))
        k = bpy.context.object; k.scale = (1.0, 0.92, 1.0); k.data.materials.append(P["dark"])
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.52, depth=0.08, location=(0, 0.05, 0.97),
                                            rotation=(0, 0, math.pi / 8))
        c = bpy.context.object; c.scale = (1.0, 0.92, 1.0); c.data.materials.append(P["steel"])
        # The roof: plated, its seams dark, a hazard edge to the south, a vent row; a raised machinery box to the north.
        for px_ in (-0.75, 0.0, 0.75):
            B(0.68, 1.15, 0.03, px_, -0.45, 1.0, P["dark"] if px_ == 0.0 else tan)
        B(2.3, 0.08, 0.04, 0, -1.08, 1.0, P["hazard"])
        for k2 in range(5):
            B(0.08, 0.32, 0.06, -0.55 + k2 * 0.12, -0.55, 1.03, P["steel"])
        B(1.9, 0.9, 0.32, 0, 0.55, 1.0, P["steel"])
        B(1.92, 0.06, 0.05, 0, 0.1, 1.28, P["hazard"])
        for fx in (-0.5, 0.5):
            lpkit.cyl(0.36, 0.1, fx, 0.55, 1.32, P["dark"], verts=24)
            lpkit.torus(0.36, 0.03, fx, 0.55, 1.42, P["steel"])
        B(0.5, 0.5, 0.18, 0.95, -0.35, 1.0, rust)                                     # a rusted service hatch
        lpkit.cyl(0.13, 0.75, -1.0, -0.35, 1.0, P["steel"], verts=16)                  # exhaust stack
        lpkit.cyl(0.15, 0.06, -1.0, -0.35, 1.72, P["dark"], verts=16)
        # The bay door: a deep frame in hazard stripes, the door's slats, the strip over it.
        B(1.3, 0.24, 0.86, 0, -1.28, 0.0, P["dark"])
        B(1.12, 0.03, 0.76, 0, -1.37, 0.04, P["rubber"])                              # the recess, deep and dark
        for k2 in range(9):
            B(1.08, 0.04, 0.05, 0, -1.385, 0.08 + k2 * 0.08, P["dark"] if k2 % 2 else P["steel"])
        for k2 in range(6):                                                           # hazard chevrons up the jambs
            for x in (-0.62, 0.62):
                B(0.08, 0.05, 0.07, x, -1.41, 0.1 + k2 * 0.13, P["hazard"] if k2 % 2 == 0 else P["dark"])
        B(1.26, 0.05, 0.06, 0, -1.41, 0.84, P["strip"])
        # The control window, lit, to the left of the door; a cable run up the wall to the deck.
        B(0.42, 0.05, 0.2, -0.95, -1.17, 0.55, P["window"])
        B(0.48, 0.06, 0.04, -0.95, -1.18, 0.67, P["steel"])
        lpkit.rod((1.05, -1.1, 0.2), (1.05, -1.1, 0.95), 0.03, P["dark"])
        lpkit.rod((1.05, -1.1, 0.95), (0.7, 0.1, 1.05), 0.03, P["dark"])
        # The amber lamp over the door's right corner.
        lpkit.cyl(0.07, 0.08, 0.72, -1.18, 0.98, P["dark"], verts=12)
        lpkit.sphere(0.07, 0.72, -1.18, 1.1, P["lamp"])
        # Pipe stubs on the sides (Factorio's machines show their connections).
        for sx in (-1, 1):
            lpkit.cyl(0.11, 0.18, sx * 1.42, 0.05, 0.25, P["steel"], verts=12, rot=(0, math.pi / 2, 0))
    def build_fans():
        for fx in (-0.5, 0.5):
            for k2 in range(4):
                a = k2 * math.pi / 2
                B(0.6, 0.11, 0.02, fx + math.cos(a) * 0.15, 0.55 + math.sin(a) * 0.15, 1.38, P["steel"], rot=a)
            lpkit.cyl(0.06, 0.05, fx, 0.55, 1.38, P["dark"], verts=12)
    model = group(build)
    blades = group(build_fans)
    pivots = []
    for fx in (-0.5, 0.5):
        bpy.ops.object.empty_add(location=(fx, 0.55, 1.4)); pv = bpy.context.object; pivots.append(pv)
        for o in blades:
            if abs(o.location.x - fx) < 0.3:
                o.parent = pv; o.matrix_parent_inverse = pv.matrix_world.inverted()
    def set_frame(f):
        t = f / FRAMES
        for i, pv in enumerate(pivots):
            pv.rotation_euler = (0, 0, (1 if i else -1) * t * math.pi / 2)            # a quarter turn: four blades loop
        lpkit.emission(P["strip"], 1.2 + 1.0 * math.sin(t * 2 * math.pi))
        lpkit.emission(P["lamp"], 4.0 if (f % 8) < 3 else 0.6)
        bpy.context.view_layer.update()
    allm = model + blades
    lpkit.bevel_all(allm)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, set_frame, allm, {P["window"], P["strip"], P["lamp"]}, ground, sun, world)
else:
    # The muster point (the user, 2026-11-04: "Probably needs an antenna of some kind. And why not a built in light"): a
    # post on a small foot, a radio box, a whip antenna with a lit tip, and a floodlight head facing the rally ground.
    FRAMES, TILES, MARGIN = 1, 1, 1.6
    tan = lpkit.worn("tan", (0.36, 0.32, 0.25), metal=0.3, rough=0.6, seams=6)
    def build():
        lpkit.cyl(0.3, 0.1, 0, 0, 0, P["dark"], verts=8)                         # foot
        lpkit.cyl(0.07, 1.0, 0, 0, 0.1, P["steel"], verts=12)                    # post
        B(0.3, 0.2, 0.32, 0, -0.12, 0.3, tan)                                    # radio box
        B(0.2, 0.02, 0.08, 0, -0.23, 0.5, P["window"])                           # its lit dial
        B(0.32, 0.22, 0.04, 0, -0.12, 0.63, P["steel"])
        lpkit.rod((0.1, -0.05, 0.63), (0.12, -0.04, 1.75), 0.008, P["steel"])    # whip antenna
        lpkit.sphere(0.035, 0.12, -0.04, 1.77, P["window"])                      # its tip, lit
        B(0.28, 0.12, 0.05, 0, 0, 1.1, P["steel"])                               # floodlight arm
        B(0.2, 0.16, 0.14, -0.12, -0.08, 1.08, P["dark"], rot=math.radians(-20))  # its head
        B(0.16, 0.02, 0.1, -0.12, -0.17, 1.06, P["window"], rot=math.radians(-20))
        B(0.06, 0.04, 0.14, 0.0, -0.22, 0.12, P["hazard"])                       # a hazard band on the foot
    model = group(build)
    lpkit.bevel_all(model)
    ground, sun, world = lpkit.stage(scene, TILES, MARGIN)
    lpkit.passes(scene, out, FRAMES, lambda f: None, model, {P["window"]}, ground, sun, world)
print("rendered", WHAT, out)
