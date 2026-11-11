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


def M(name, rgb, metal=0.5, rough=0.5, emit=None, strength=0.0, grime=0.4):
    return lpkit.mat(name, rgb, metal=metal, rough=rough, emit=emit, strength=strength, grime=grime)


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
RB = 0.85


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
    # (Raised by RB, 0.2.325: the user's rating, "Raise it?": at 1.75 it stood as low as the combinators round it.)
    rod((0.18, -0.1, 0.38), (0.18, -0.1, 1.75 + RB), 0.05, STEEL, verts=12)
    for z in (0.7, 1.1, 1.5, 1.9):
        lpkit.torus(0.055, 0.015, 0.18, -0.1, z, DARK)
    rod((0.05, 0.0, 0.38), (0.16, -0.08, 0.6), 0.02, RUBBER, verts=6)
    cyl(0.06, 0.1, 0.18, -0.1, 0.38, DARK, verts=12)
    # The pennant: a thin swept plate off the mast.
    # A triangular pennant off the mast, swept back (a square plane read as a sign panel, the first film).
    import bmesh
    bm = bmesh.new()
    v0 = bm.verts.new((0.0, 0, 0.17)); v1 = bm.verts.new((0.0, 0, -0.17)); v2 = bm.verts.new((0.5, 0, 0.0))
    bm.faces.new((v0, v1, v2))
    me = bpy.data.meshes.new("pennant"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("pennant", me); scene.collection.objects.link(o)
    o.location = (0.21, -0.1, 1.55 + RB); o.rotation_euler = (0, 0, math.radians(-25))
    sol = o.modifiers.new("t", "SOLIDIFY"); sol.thickness = 0.012
    me.materials.append(PENNANT)
    B(0.06, 0.014, 0.24, 0.22, -0.1, 1.38 + RB, HAZ, bevel=0.0)
    # Two loudspeaker horns on a crossbar under the lamp (the user's rating: "Perhaps we include a speaker?").
    rod((0.0, -0.1, 1.3 + RB), (0.36, -0.1, 1.3 + RB), 0.018, STEEL, verts=6)
    for x, yaw in ((0.02, 35), (0.34, -35)):
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.035, radius2=0.12, depth=0.22, location=(x, -0.2, 1.25 + RB),
                                        rotation=(math.radians(-80), 0, math.radians(yaw)), end_fill_type="NOTHING")
        o = bpy.context.object; o.modifiers.new("t", "SOLIDIFY").thickness = 0.015; o.data.materials.append(HAZ)
        cyl(0.045, 0.08, x, -0.1, 1.21 + RB, DARK, verts=10)
    # Its lamp: a cage, the lamp inside (lit, the glow's frames turn it).
    cyl(0.07, 0.04, 0.18, -0.1, 1.74 + RB, DARK, verts=16)
    lamp = sph(0.065, 0.18, -0.1, 1.86 + RB, AMBER)
    for k in range(4):
        a = k * math.pi / 2
        rod((0.18 + math.cos(a) * 0.08, -0.1 + math.sin(a) * 0.08, 1.78 + RB), (0.18 + math.cos(a) * 0.08, -0.1 + math.sin(a) * 0.08, 1.95 + RB),
            0.008, STEEL, verts=6)
    cyl(0.085, 0.02, 0.18, -0.1, 1.95 + RB, DARK, verts=16)
    for a in (0.6, 2.7, 4.8):
        rod((0.18, -0.1, 1.2 + RB), (0.18 + math.cos(a) * 0.38, -0.1 + math.sin(a) * 0.38, 0.08), 0.006, RUBBER, verts=4)
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
VIOLET = M("violet", (0.3, 0.08, 0.55), 0.1, 0.1, emit=(0.6, 0.2, 1.0), strength=0.0)
BLUE = M("bluelight", (0.1, 0.2, 0.5), 0.1, 0.3, emit=(0.3, 0.55, 1.0), strength=0.0)
GLASS = M("glass", (0.6, 0.7, 0.75), 0.0, 0.05)
if os.path.isdir(lptex.TEX):
    OCHRE = lptex.textured("ochre-t", "PaintedMetal004", hue=0.62, sat=0.7, val=0.55, scale=2.5, edge=(0.45, 0.4, 0.33), rough_add=0.15)
    RUST = lptex.textured("rust-t", "MetalPlates013", val=0.55, scale=2.0, edge=(0.4, 0.33, 0.25))
    KHBLUE = lptex.textured("khblue-t", "PaintedMetal006", hue=0.62, sat=0.35, val=0.45, scale=2.5, edge=(0.45, 0.46, 0.47))
GLOWING |= {GREEN, VIOLET, BLUE}
# (The redo after the user's ratings, 2026-11-10: "It's a box?", "What is this supposed to be?", "will disappear against
# desert: a bright flag and a dark pole?". Each small building now carries one saturated, readable element on a dark
# body: a striped awning, a flag, a dish with its crystal, loudspeakers.)
FLAG = M("flag", (0.82, 0.17, 0.03), 0.0, 0.7, grime=0.25)       # Grubstake's claim colour, vivid: seen on desert
CANVAS = M("canvas", (0.62, 0.56, 0.44), 0.0, 0.85)            # worn canvas, the awning's light stripes
PENNANT = M("pennant", (0.62, 0.07, 0.04), 0.0, 0.7, grime=0.25)   # the rally beacon's: red, seen on grass and sand
POLE = M("pole", (0.035, 0.035, 0.04), 0.7, 0.5)


ANIM = {}   # name -> f(frame): a building whose body moves (each frame's body and shadow rendered)


def lantern(x, y, z, m=AMBER):
    cyl(0.05, 0.03, x, y, z, DARK, verts=12)
    sph(0.045, x, y, z + 0.08, m)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        rod((x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, z + 0.03), (x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, z + 0.14), 0.006, STEEL, verts=5)
    cyl(0.06, 0.02, x, y, z + 0.14, DARK, verts=12)


def claim_marker(f):
    # A Grubstake claim: a dark steel pole, banded at its foot, set in a footing; a large flag in Grubstake's vivid
    # orange, rippled, its hoist band dark; a lantern on the footing; three guy wires. The flag reads from afar.
    bevel(B(0.32, 0.32, 0.1, 0, 0, 0, DARK), 0.02)
    rod((0, 0, 0.1), (0, 0, 2.0), 0.035, POLE, verts=10)
    for k in range(3):
        cyl(0.05, 0.06, 0, 0, 0.14 + k * 0.12, HAZ if k % 2 == 0 else POLE, verts=12)
    sph(0.05, 0, 0, 2.02, STEEL)
    import bmesh
    bm = bmesh.new()
    NX, NZ, W, H = 10, 4, 0.72, 0.46
    NX = 14
    grid = [[bm.verts.new((0.04 + W * i / NX, 0.0, 1.95 - H * j / NZ)) for j in range(NZ + 1)] for i in range(NX + 1)]
    for i in range(NX):
        for j in range(NZ):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    me = bpy.data.meshes.new("flag"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("flag", me); scene.collection.objects.link(o)
    o.rotation_euler = (0, 0, math.radians(-12)); o.modifiers.new("t", "SOLIDIFY").thickness = 0.014
    me.materials.append(FLAG)
    # (Waving, 0.2.325: the user asked whether the flag flapped; its body was one frame. A travelling wave from the hoist
    # out, growing to the fly, the fly's corner lifting and dropping, over the body's frames.)
    def wave(fr):
        ph = fr / GLOW_FRAMES * 2 * math.pi
        for i in range(NX + 1):
            u = i / NX
            for j in range(NZ + 1):
                v = me.vertices[i * (NZ + 1) + j]
                v.co.y = 0.11 * u * math.sin(u * 2.4 * math.pi - ph) + 0.02 * u * math.sin(ph * 2 + j)
                v.co.x = 0.04 + W * u * (1 - 0.06 * u * (0.5 + 0.5 * math.cos(u * 2.4 * math.pi - ph)))
                v.co.z = 1.95 - H * j / NZ - 0.05 * u * u * (0.6 + 0.4 * math.sin(ph - u * 3))
        me.update()
    ANIM["claim-marker"] = wave
    B(0.07, 0.03, H, 0.05, 0.0, 1.95 - H, POLE, bevel=0.0).rotation_euler = (0, 0, math.radians(-12))
    lantern(0.12, -0.12, 0.1)
    for a in (0.8, 2.6, 4.6):
        rod((0, 0, 1.3), (math.cos(a) * 0.46, math.sin(a) * 0.46, 0.0), 0.006, RUBBER, verts=4)
        cyl(0.025, 0.05, math.cos(a) * 0.46, math.sin(a) * 0.46, 0.0, STEEL, verts=6)


def pact_breaker(f):
    # (Redone, 0.2.325; the user's rating, "What does this building do?": the upturned dish of 0.2.321 read as one more
    # radar.) A jammer aimed down at the biters: a hazard-edged skid, a dark A-frame mast, at its head the pacifier
    # crystal glowing violet in an armoured cage, three horn emitters hung under it pointing down and out at the
    # ground, the jamming field a violet ring pulsing on the ground round it; a battery box, cables, a red strobe on top.
    bevel(B(0.92, 0.92, 0.06, 0, 0, 0, DARK), 0.01)
    for (sx, sy, w, d) in ((0, -0.45, 0.92, 0.04), (0, 0.45, 0.92, 0.04), (-0.45, 0, 0.04, 0.92), (0.45, 0, 0.04, 0.92)):
        for k in range(6):
            if w > d:
                B(w / 6, d, 0.065, -0.46 + w / 6 * (k + 0.5), sy, 0, HAZ if k % 2 == 0 else POLE, bevel=0.0)
            else:
                B(w, d / 6, 0.065, sx, -0.46 + d / 6 * (k + 0.5), 0, HAZ if k % 2 == 0 else POLE, bevel=0.0)
    bevel(B(0.3, 0.22, 0.26, 0.28, 0.3, 0.06, DARK), 0.02)
    B(0.22, 0.02, 0.05, 0.28, 0.18, 0.24, HAZ, bevel=0.0)
    head = V((0, 0, 1.25))
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod((sx * 0.36, sy * 0.36, 0.06), (sx * 0.06, sy * 0.06, head.z - 0.05), 0.026, POLE, verts=8)
    for z in (0.45, 0.8):
        k = 1 - (z - 0.06) / (head.z - 0.11)
        r = 0.06 + 0.3 * k
        for (a, b) in (((-r, -r), (r, -r)), ((r, -r), (r, r)), ((r, r), (-r, r)), ((-r, r), (-r, -r))):
            rod((a[0], a[1], z), (b[0], b[1], z), 0.012, POLE, verts=5)
    # The crystal's housing: an armoured octagonal cage, the crystal showing violet through its slots.
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.16, depth=0.08, location=(0, 0, head.z - 0.02))
    bpy.context.object.data.materials.append(DARK)
    for k in range(5):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.055 - 0.006 * k, depth=0.22 + 0.06 * (k % 2),
                                            location=(-0.05 + (k % 3) * 0.05, -0.02 + (k // 3) * 0.04, head.z + 0.14),
                                            rotation=(0.25 * (k - 2), 0.2 * (k - 2), 0))
        bpy.context.object.data.materials.append(VIOLET)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        rod((math.cos(a) * 0.15, math.sin(a) * 0.15, head.z + 0.02), (math.cos(a) * 0.12, math.sin(a) * 0.12, head.z + 0.3), 0.016, DARK, verts=5)
    cyl(0.15, 0.03, 0, 0, head.z + 0.3, DARK, verts=8)
    cyl(0.03, 0.06, 0, 0, head.z + 0.33, DARK, verts=8)
    sph(0.045, 0, 0, head.z + 0.42, RED)
    # Three horns hung under the head, pointing down and out at the ground: a jammer aimed at what is under it.
    for a in (math.pi / 2 + 0.3, math.pi / 2 + 2.4, math.pi / 2 + 4.5):
        out_ = V((math.cos(a), math.sin(a), 0))
        root = head + V((0, 0, -0.1)) + out_ * 0.1
        mouth = root + out_ * 0.22 + V((0, 0, -0.36))
        d = mouth - root
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.035, radius2=0.13, depth=d.length, location=tuple((root + mouth) / 2),
                                        end_fill_type="NOTHING")
        o = bpy.context.object; o.rotation_mode = "QUATERNION"; o.rotation_quaternion = d.to_track_quat("Z", "Y")
        o.modifiers.new("t", "SOLIDIFY").thickness = 0.015; o.data.materials.append(DARK)
        rim = lpkit.torus(0.13, 0.014, *tuple(mouth), HAZ); rim.rotation_mode = "QUATERNION"; rim.rotation_quaternion = d.to_track_quat("Z", "Y")
        # (Its throat lit violet: the emitter's mouth, seen from above.)
        bpy.ops.mesh.primitive_circle_add(vertices=20, radius=0.11, fill_type="NGON", location=tuple(mouth - d.normalized() * 0.03))
        c = bpy.context.object; c.rotation_mode = "QUATERNION"; c.rotation_quaternion = d.to_track_quat("Z", "Y"); c.data.materials.append(VIOLET)
        rod(tuple(root), tuple(head + V((0, 0, -0.04))), 0.02, DARK, verts=6)
    # The jamming field: a thin violet ring on the ground, round the skid.
    ring = lpkit.torus(0.62, 0.018, 0, 0, 0.015, VIOLET); ring.scale = (1, 1, 0.3)
    rod((0.28, 0.2, 0.32), (0.06, 0.06, head.z - 0.1), 0.02, RUBBER, verts=6)
    rod((0.4, 0.38, 0.2), (0.5, 0.48, 0.0), 0.02, RUBBER, verts=6)


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
    # (Its cloud, 0.2.325; the user's rating: "Needs a larger cloud or series of clouds": a train of puffs from the nozzle,
    # each swelling and thinning as it drifts off downwind, over the body's frames; no shadow, a gas.)
    puffs = []
    N = 9
    for k in range(N):
        m = bpy.data.materials.new(f"mist{k}"); m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.36, 0.42, 0.16, 1)
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Emission Color"].default_value = (0.55, 0.9, 0.2, 1)
        bsdf.inputs["Emission Strength"].default_value = 0.04
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(0, 0, 0))
        o = bpy.context.object; o.data.materials.append(m); o.visible_shadow = False
        o.modifiers.new("d", "DISPLACE").strength = 0.18
        tx = bpy.data.textures.new(f"mistn{k}", "CLOUDS"); tx.noise_scale = 0.6; o.modifiers["d"].texture = tx
        puffs.append((o, bsdf))
    def drift(fr):
        t = fr / GLOW_FRAMES
        for k, (o, bsdf) in enumerate(puffs):
            p = (t + k / N) % 1.0
            o.location = (0.05 + 1.0 * p, -0.1 - 0.3 * p, 1.0 + 0.6 * p - 0.2 * p * p)
            r = 0.05 + 0.42 * p ** 0.8
            o.scale = (r * 1.2, r, r * 0.8)
            o.rotation_euler = (0, 0, k + p * 2)
            bsdf.inputs["Alpha"].default_value = 0.42 * min(1.0, p * 5) * (1 - p) ** 1.5
        bpy.context.view_layer.update()
    ANIM["pheromone-bait"] = drift


MODELS = {"rally-beacon": (rally_beacon, ["north", "east", "south", "west"]),
          "threat-scanner": (threat_scanner, ["north", "east", "south", "west"]),
          "claim-marker": (claim_marker, ["north"]), "pact-breaker": (pact_breaker, ["north"]),
          "pheromone-bait": (pheromone_bait, ["north"])}
# Each frame's glow: the beacon's lamp pulses round (a rotating beacon's flash), the scanner's sweep light pulses.
def glow(name, f):
    t = f / GLOW_FRAMES
    lpkit.emission(AMBER, 4.0 * max(0.0, math.cos(t * 2 * math.pi)) ** 2 + 0.4)
    lpkit.emission(RED, 3.0 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)) + 0.3)
    lpkit.emission(GREEN, 0.5 + 0.3 * math.sin(t * 2 * math.pi))
    lpkit.emission(VIOLET, 1.0 + 0.5 * math.sin(t * 4 * math.pi))
    lpkit.emission(BLUE, 4.0 * max(0.0, math.sin(t * 2 * math.pi)) ** 4 + 0.2)


YAW = {"north": 0, "east": 270, "south": 180, "west": 90}
FILL = 0.38
ground, sun, world = lpkit.stage(scene, 4, 1)   # (a margin: the claim marker's flag pole is two tiles tall, its shadow long)
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
        moving = name in ANIM
        if moving: os.makedirs(f"{o}/shadow", exist_ok=True)
        for f in range(GLOW_FRAMES):
            glow(name, f)
            if moving: ANIM[name](f)
            if f == 0 or moving:
                ground.hide_render = True; sun.hide_render = False; bg.inputs[1].default_value = FILL
                for m in model: m.is_holdout = False
                lpkit.render(scene, f"{o}/body/{f:03d}.png")
            ground.hide_render = True; sun.hide_render = True; bg.inputs[1].default_value = 0.0
            for m in model:
                ms = [s.material for s in m.material_slots if s.material]
                m.is_holdout = not any(x in GLOWING for x in ms)
            lpkit.render(scene, f"{o}/glow/{f:03d}.png")
            if moving:
                for m in model: m.is_holdout = False; m.visible_camera = False
                sun.hide_render = False; bg.inputs[1].default_value = FILL; ground.hide_render = False
                lpkit.render(scene, f"{o}/shadow/{f:03d}.png")
                for m in model: m.visible_camera = True
        if moving: ANIM[name](0)
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
