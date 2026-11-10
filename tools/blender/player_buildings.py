"""The player's own small buildings, modelled (the user, 2026-11-10: "I still see some gross recolors. Why not use blender
again?"): each was a vanilla sprite, a rally beacon and a threat scanner the same constant combinator. One script, a
function a building; four directions where the building turns (a combinator), its body once, its glow GLOW_FRAMES times,
its shadow; and for a combinator its red and green wire posts' tips projected to the screen (posts.json: tiles from the
entity's centre, its shadow's too) for its circuit_wire_connection_points.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/player_buildings.py -- <out dir> [name ...]
    then: uv run --with pillow python tools/blender/cannon_sheets.py <out dir>/<name> landing-party/graphics/player/<name>
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = set(args[1:])
GLOW_FRAMES = int(os.environ.get("LP_FRAMES", 8))
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
lpkit.gpu(scene)
V = mathutils.Vector
B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere


def M(name, rgb, metal=0.5, rough=0.5, emit=None, strength=0.0):
    return lpkit.mat(name, rgb, metal=metal, rough=rough, emit=emit, strength=strength, grime=0.4)


STEEL = M("steel", (0.3, 0.31, 0.33), 0.8, 0.4)
DARK = M("dark", (0.06, 0.065, 0.07), 0.6, 0.55)
PAINT = M("paint", (0.18, 0.26, 0.2), 0.3, 0.6)          # the army's olive green
HAZ = M("haz", (0.7, 0.55, 0.1), 0.2, 0.6)
COPPER = M("copper", (0.5, 0.26, 0.12), 0.9, 0.4)
RUBBER = M("rubber", (0.03, 0.03, 0.03), 0.0, 0.85)
WIRE_R = M("wire-r", (0.55, 0.08, 0.06), 0.3, 0.4)
WIRE_G = M("wire-g", (0.1, 0.45, 0.12), 0.3, 0.4)
if os.path.isdir(lptex.TEX):
    STEEL = lptex.textured("steel-t", "Metal038", val=0.7, scale=3.0, edge=(0.5, 0.5, 0.5), dirt=0.7, rough_add=0.1)
    DARK = lptex.textured("dark-t", "Metal038", val=0.3, scale=3.0, edge=(0.3, 0.3, 0.29), dirt=0.6, rough_add=0.25)
    PAINT = lptex.textured("paint-t", "PaintedMetal006", hue=0.45, sat=0.5, val=0.55, scale=2.5, edge=(0.45, 0.45, 0.42))
    HAZ = lptex.textured("haz-t", "PaintedMetal004", hue=0.66, sat=0.55, val=0.62, scale=2.5, edge=(0.42, 0.41, 0.38), rough_add=0.2)
AMBER = M("amber", (0.6, 0.4, 0.05), 0.1, 0.3, emit=(1.0, 0.65, 0.15), strength=0.0)
RED = M("redlight", (0.4, 0.05, 0.03), 0.1, 0.3, emit=(1.0, 0.18, 0.1), strength=0.0)
LENS = M("lens", (0.05, 0.08, 0.1), 0.2, 0.08)
GLOWING = {AMBER, RED}


def bevel(o, w=0.02, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"; return o


def posts(x, y, z):
    """The red and green wire posts on a box's top at (x, y, z): their tips, for the wire points."""
    tips = {}
    for col, dx, m in (("red", -0.11, WIRE_R), ("green", 0.11, WIRE_G)):
        cyl(0.035, 0.12, x + dx, y, z, DARK, verts=10)
        cyl(0.045, 0.04, x + dx, y, z + 0.12, m, verts=10)
        tips[col] = V((x + dx, y, z + 0.16))
    return tips


# --- The buildings (1 tile: x, y in -0.5..0.5) ---------------------------------------------------------------------
def rally_beacon(f):
    # A terminal box on a footed plate; a mast with a pennant in the army's green; a rotating amber lamp on top.
    bevel(B(0.8, 0.8, 0.08, 0, 0, 0, DARK), 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(0.05, 0.03, sx * 0.32, sy * 0.32, 0.08, STEEL, verts=8)
    bevel(B(0.5, 0.38, 0.3, 0, 0.1, 0.08, PAINT), 0.03)
    B(0.36, 0.02, 0.18, 0, -0.1, 0.14, DARK, bevel=0.0)
    for k in range(3):
        B(0.05, 0.01, 0.03, -0.1 + k * 0.1, -0.11, 0.26, AMBER if k == 1 else DARK, bevel=0.0)
    tips = posts(0, 0.18, 0.38)
    rod((0.18, -0.1, 0.38), (0.18, -0.1, 1.75), 0.05, STEEL, verts=12)
    for z in (0.7, 1.1):
        lpkit.torus(0.055, 0.015, 0.18, -0.1, z, DARK)
    rod((0.05, 0.0, 0.38), (0.16, -0.08, 0.6), 0.02, RUBBER, verts=6)
    cyl(0.06, 0.1, 0.18, -0.1, 0.38, DARK, verts=12)
    # The pennant: a thin swept plate off the mast.
    # A triangular pennant off the mast, swept back (a square plane read as a sign panel, the first film).
    import bmesh
    bm = bmesh.new()
    v0 = bm.verts.new((0.0, 0, 0.12)); v1 = bm.verts.new((0.0, 0, -0.12)); v2 = bm.verts.new((0.34, 0, 0.0))
    bm.faces.new((v0, v1, v2))
    me = bpy.data.meshes.new("pennant"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("pennant", me); scene.collection.objects.link(o)
    o.location = (0.21, -0.1, 1.5); o.rotation_euler = (0, 0, math.radians(-25))
    sol = o.modifiers.new("t", "SOLIDIFY"); sol.thickness = 0.012
    me.materials.append(PAINT)
    B(0.06, 0.014, 0.24, 0.22, -0.1, 1.38, HAZ, bevel=0.0)
    # Its lamp: a cage, the lamp inside (lit, the glow's frames turn it).
    cyl(0.07, 0.04, 0.18, -0.1, 1.74, DARK, verts=16)
    lamp = sph(0.065, 0.18, -0.1, 1.86, AMBER)
    for k in range(4):
        a = k * math.pi / 2
        rod((0.18 + math.cos(a) * 0.08, -0.1 + math.sin(a) * 0.08, 1.78), (0.18 + math.cos(a) * 0.08, -0.1 + math.sin(a) * 0.08, 1.95),
            0.008, STEEL, verts=6)
    cyl(0.085, 0.02, 0.18, -0.1, 1.95, DARK, verts=16)
    return tips


def threat_scanner(f):
    # Low and wide: an armoured box, a sensor head on a turntable, its lens and red sweep light, two short antennae.
    bevel(B(0.84, 0.76, 0.32, 0, 0, 0, DARK), 0.04)
    bevel(B(0.74, 0.66, 0.06, 0, 0, 0.32, PAINT), 0.02)
    for k in range(4):
        B(0.6, 0.02, 0.03, 0, -0.39, 0.07 + k * 0.06, STEEL, bevel=0.0)
    cyl(0.24, 0.06, -0.05, 0.03, 0.38, STEEL, verts=32)
    head = bevel(B(0.34, 0.26, 0.2, -0.05, 0.03, 0.44, PAINT), 0.04)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.08, depth=0.06, location=(-0.05, -0.12, 0.54), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(LENS)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.085, minor_radius=0.015, location=(-0.05, -0.155, 0.54), rotation=(math.pi / 2, 0, 0))
    bpy.context.object.data.materials.append(RED)
    B(0.26, 0.02, 0.03, -0.05, -0.115, 0.62, RED, bevel=0.0)
    for x in (-0.2, 0.1):
        rod((x, 0.12, 0.64), (x + 0.02, 0.14, 0.98 if x < 0 else 0.86), 0.012, STEEL, verts=6)
        sph(0.02, x + 0.02, 0.14, 0.98 if x < 0 else 0.86, RED)
    B(0.18, 0.02, 0.06, 0.22, -0.39, 0.2, HAZ, bevel=0.0)
    return posts(0.26, 0.22, 0.38)


OCHRE = M("ochre", (0.52, 0.33, 0.1), 0.3, 0.6)
RUST = M("rust", (0.25, 0.11, 0.05), 0.5, 0.7)
WOOD = M("wood", (0.28, 0.17, 0.08), 0.0, 0.8)
KHBLUE = M("khblue", (0.12, 0.17, 0.24), 0.5, 0.5)
WHITE = M("white", (0.42, 0.43, 0.42), 0.2, 0.6)
GREEN = M("greenlight", (0.2, 0.5, 0.1), 0.1, 0.2, emit=(0.6, 1.0, 0.25), strength=0.0)
VIOLET = M("violet", (0.4, 0.2, 0.6), 0.1, 0.1, emit=(0.65, 0.35, 1.0), strength=0.0)
BLUE = M("bluelight", (0.1, 0.2, 0.5), 0.1, 0.3, emit=(0.3, 0.55, 1.0), strength=0.0)
GLASS = M("glass", (0.6, 0.7, 0.75), 0.0, 0.05)
if os.path.isdir(lptex.TEX):
    OCHRE = lptex.textured("ochre-t", "PaintedMetal004", hue=0.62, sat=0.7, val=0.55, scale=2.5, edge=(0.45, 0.4, 0.33), rough_add=0.15)
    RUST = lptex.textured("rust-t", "MetalPlates013", val=0.55, scale=2.0, edge=(0.4, 0.33, 0.25))
    KHBLUE = lptex.textured("khblue-t", "PaintedMetal006", hue=0.62, sat=0.35, val=0.45, scale=2.5, edge=(0.45, 0.46, 0.47))
GLOWING |= {GREEN, VIOLET, BLUE}


def lantern(x, y, z, m=AMBER):
    cyl(0.05, 0.03, x, y, z, DARK, verts=12)
    sph(0.045, x, y, z + 0.08, m)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        rod((x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, z + 0.03), (x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, z + 0.14), 0.006, STEEL, verts=5)
    cyl(0.06, 0.02, x, y, z + 0.14, DARK, verts=12)


def trade_post(f):
    # Grubstake's trading kiosk: a patched crate, an awning on two posts, a pay hatch, a lantern, a tally board.
    bevel(B(0.74, 0.6, 0.5, 0, 0.05, 0, RUST), 0.02)
    for k in range(3):
        B(0.76, 0.02, 0.05, 0, -0.26, 0.08 + k * 0.17, WOOD, bevel=0.005)
    bevel(B(0.3, 0.03, 0.18, -0.12, -0.27, 0.22, DARK), 0.01)
    B(0.12, 0.01, 0.02, -0.12, -0.285, 0.33, AMBER, bevel=0.0)
    for x in (-0.36, 0.36):
        rod((x, -0.32, 0.0), (x, -0.32, 0.85), 0.022, WOOD, verts=6)
    o = B(0.86, 0.36, 0.03, 0, -0.18, 0.82, OCHRE, bevel=0.005); o.rotation_euler = (math.radians(-14), 0, 0)
    for k in range(4):
        B(0.2, 0.37, 0.032, -0.32 + k * 0.215, -0.18, 0.822, RUST if k % 2 else OCHRE, bevel=0.0).rotation_euler = (math.radians(-14), 0, 0)
    bevel(B(0.26, 0.02, 0.16, 0.18, -0.28, 0.5, WOOD), 0.005)
    lantern(0.3, -0.32, 0.86)
    cyl(0.1, 0.12, 0.25, 0.22, 0.5, STEEL, verts=16)


def border_stake(f):
    # Kessler-Hayashi's survey stake: a driven pile, banded, a survey plate, a blinking blue light on top.
    cyl(0.16, 0.06, 0, 0, 0, DARK, verts=16)
    for k in range(6):
        cyl(0.07, 0.2, 0, 0, 0.06 + k * 0.2, KHBLUE if k % 2 == 0 else WHITE, verts=16)
    lpkit.torus(0.075, 0.015, 0, 0, 0.7, HAZ)
    bevel(B(0.3, 0.02, 0.22, 0.1, -0.08, 0.55, KHBLUE), 0.01)
    B(0.22, 0.022, 0.03, 0.1, -0.09, 0.7, HAZ, bevel=0.0)
    B(0.18, 0.022, 0.08, 0.1, -0.09, 0.6, WHITE, bevel=0.0)
    cyl(0.05, 0.05, 0, 0, 1.26, DARK, verts=12)
    sph(0.05, 0, 0, 1.34, BLUE)
    for a in (0.3, 2.4, 4.4):
        rod((0, 0, 0.0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), 0.01, DARK, verts=4)


def claim_marker(f):
    # A Grubstake claim: a stake with its ochre flag, a claim plaque nailed on, a lantern at its foot, guy ropes.
    rod((0, 0, 0), (0, 0, 1.4), 0.03, WOOD, verts=8)
    import bmesh
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((0.0, 0, 1.38), (0.0, 0, 1.08), (0.38, 0, 1.2), (0.34, 0, 1.33))]
    bm.faces.new(vs)
    me = bpy.data.meshes.new("flag"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("flag", me); scene.collection.objects.link(o); o.location = (0.03, 0, 0)
    o.rotation_euler = (0, 0, math.radians(-20)); o.modifiers.new("t", "SOLIDIFY").thickness = 0.012; me.materials.append(OCHRE)
    bevel(B(0.24, 0.02, 0.16, 0, -0.035, 0.6, WOOD), 0.005)
    B(0.16, 0.022, 0.03, 0, -0.04, 0.64, OCHRE, bevel=0.0)
    lantern(0.18, -0.12, 0.0)
    for a in (0.8, 2.6, 4.6):
        rod((0, 0, 0.9), (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), 0.006, RUBBER, verts=4)
        cyl(0.02, 0.05, math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0, STEEL, verts=6)


def pact_breaker(f):
    # A jammer: a crate, its pacifier crystal glowing in a cage, a tall jamming antenna, cables.
    bevel(B(0.7, 0.6, 0.36, 0, 0.05, 0, OCHRE), 0.03)
    bevel(B(0.62, 0.52, 0.04, 0, 0.05, 0.36, DARK), 0.01)
    for k in range(5):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.05 - 0.005 * k, depth=0.2 + 0.05 * (k % 2),
                                            location=(-0.12 + (k % 3) * 0.06, -0.05 + (k // 3) * 0.06, 0.5), rotation=(0.2 * (k - 2), 0.15 * k, 0))
        bpy.context.object.data.materials.append(VIOLET)
    for k in range(6):
        a = k * math.pi / 3
        rod((-0.06 + math.cos(a) * 0.17, -0.02 + math.sin(a) * 0.17, 0.4), (-0.06 + math.cos(a) * 0.15, -0.02 + math.sin(a) * 0.15, 0.68), 0.01, STEEL, verts=5)
    lpkit.torus(0.17, 0.02, -0.06, -0.02, 0.68, DARK)
    rod((0.22, 0.18, 0.4), (0.24, 0.2, 1.35), 0.018, STEEL, verts=6)
    for z in (0.75, 1.0, 1.2):
        rod((0.13, 0.2, z), (0.35, 0.2, z), 0.008, STEEL, verts=4)
    sph(0.03, 0.24, 0.2, 1.37, RED)
    rod((0.22, -0.25, 0.1), (0.36, -0.36, 0.0), 0.02, RUBBER, verts=6)
    B(0.2, 0.02, 0.08, 0.15, -0.25, 0.14, HAZ, bevel=0.0)


def pheromone_bait(f):
    # A pheromone sprayer: a gland sac in a cage on a tripod, its nozzle, a tank, the sac glowing green.
    for a in (0.3, 2.4, 4.5):
        rod((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), (0, 0, 0.45), 0.018, STEEL, verts=6)
    cyl(0.1, 0.06, 0, 0, 0.42, DARK, verts=16)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.17, location=(0, 0, 0.62), segments=24, ring_count=12)
    o = bpy.context.object; o.scale = (1, 0.85, 1.1); o.data.materials.append(GREEN)
    for k in range(6):
        a = k * math.pi / 3
        rod((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.47), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.8), 0.008, STEEL, verts=4)
    lpkit.torus(0.2, 0.012, 0, 0, 0.8, STEEL)
    rod((0, 0, 0.82), (0.05, -0.1, 0.95), 0.02, DARK, verts=6)
    cyl(0.03, 0.05, 0.05, -0.1, 0.95, DARK, verts=8)
    cyl(0.08, 0.28, 0.24, 0.12, 0.0, HAZ, verts=16)


MODELS = {"rally-beacon": (rally_beacon, ["north", "east", "south", "west"]),
          "threat-scanner": (threat_scanner, ["north", "east", "south", "west"]),
          "trade-post": (trade_post, ["north"]), "border-stake": (border_stake, ["north"]),
          "claim-marker": (claim_marker, ["north"]), "pact-breaker": (pact_breaker, ["north"]),
          "pheromone-bait": (pheromone_bait, ["north"])}
# Each frame's glow: the beacon's lamp pulses round (a rotating beacon's flash), the scanner's sweep light pulses.
def glow(name, f):
    t = f / GLOW_FRAMES
    lpkit.emission(AMBER, 4.0 * max(0.0, math.cos(t * 2 * math.pi)) ** 2 + 0.4)
    lpkit.emission(RED, 3.0 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)) + 0.3)
    lpkit.emission(GREEN, 0.5 + 0.3 * math.sin(t * 2 * math.pi))
    lpkit.emission(VIOLET, 2.0 + 1.0 * math.sin(t * 4 * math.pi))
    lpkit.emission(BLUE, 4.0 * max(0.0, math.sin(t * 2 * math.pi)) ** 4 + 0.2)


YAW = {"north": 0, "east": 270, "south": 180, "west": 90}
FILL = 0.38
ground, sun, world = lpkit.stage(scene, 4, 0)
sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
bg = world.node_tree.nodes["Background"]
from bpy_extras.object_utils import world_to_camera_view
for name, (fn, dirs) in MODELS.items():
    if only and name not in only:
        continue
    rig = bpy.data.objects.new("rig", None); scene.collection.objects.link(rig)
    before = set(scene.objects)
    tips = fn(0)
    model = [o for o in scene.objects if o not in before]
    for o in model:
        if o.parent is None: o.parent = rig
    meta = {}
    for d in dirs:
        rig.rotation_euler = (0, 0, math.radians(YAW[d]))
        bpy.context.view_layer.update()
        o = f"{out}/{name}/{d}"
        for k in ("body", "glow"): os.makedirs(f"{o}/{k}", exist_ok=True)
        for f in range(GLOW_FRAMES):
            glow(name, f)
            if f == 0:
                ground.hide_render = True; sun.hide_render = False; bg.inputs[1].default_value = FILL
                for m in model: m.is_holdout = False
                lpkit.render(scene, f"{o}/body/000.png")
            ground.hide_render = True; sun.hide_render = True; bg.inputs[1].default_value = 0.0
            for m in model:
                ms = [s.material for s in m.material_slots if s.material]
                m.is_holdout = not any(x in GLOWING for x in ms)
            lpkit.render(scene, f"{o}/glow/{f:03d}.png")
        for m in model: m.is_holdout = False; m.visible_camera = False
        sun.hide_render = False; bg.inputs[1].default_value = FILL; ground.hide_render = False
        glow(name, 0)
        lpkit.render(scene, f"{o}/shadow.png")
        for m in model: m.visible_camera = True
        # Its wire posts' tips on screen, in tiles from the entity's centre (64 px a tile after the sheet's sqrt(2)
        # stretch: a camera unit is a tile across, and its height on screen is the stretched one), and on its shadow
        # (where the sun throws them on the ground: z 0 along the light).
        if tips:
            W = scene.render.resolution_x
            span = scene.camera.data.ortho_scale
            light = sun.matrix_world.to_quaternion() @ V((0, 0, -1))
            pts = {}
            for col, p in tips.items():
                wp = rig.matrix_world @ p
                c = world_to_camera_view(scene, scene.camera, wp)
                x, y = (c.x - 0.5) * span, -(c.y - 0.5) * span * math.sqrt(2)
                gp = wp + light * (wp.z / max(1e-3, -light.z))
                g = world_to_camera_view(scene, scene.camera, gp)
                pts[col] = {"wire": [round(x, 3), round(y, 3)],
                            "shadow": [round((g.x - 0.5) * span, 3), round(-(g.y - 0.5) * span * math.sqrt(2), 3)]}
            meta[d] = pts
        print("rendered", name, d)
    if meta:
        json.dump(meta, open(f"{out}/{name}/posts.json", "w"), indent=1)
    for m in model + [rig]:
        bpy.data.objects.remove(m, do_unlink=True)
