"""The player's own small buildings, modelled (the user, 2026-11-10: "I still see some gross recolors. Why not use blender
again?"): each was a vanilla sprite, a rally beacon and a threat scanner the same constant combinator. One script, a
function a building; four directions where the building turns (a combinator), its body once, its glow GLOW_FRAMES times,
its shadow; and for a combinator its red and green wire posts' tips projected to the screen (posts.json: tiles from the
entity's centre, its shadow's too) for its circuit_wire_connection_points.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/player_buildings.py -- <out dir> [name ...]
    then: uv run --with pillow python tools/blender/cannon_sheets.py <out dir>/<name> landing-party-graphics/graphics/player/<name>
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


# The supply depot's robot hatch opens over vanilla's requester chest's robot_door frames (7, its opened_duration 7 ticks):
# a frame a step of the door, closed at the first.
DEPOT_FRAMES = 7
# (Metal 0.85 at first: it mirrored the grey sky and read as grey steel at 64 px, the one saturated element lost.)
# (Then (0.62, 0.42, 0.13) at roughness 0.42: still dark posts at 1x, the coordinator; warmer, and smoother to catch the sun.)
# (At metal 0.55 it still measured value 0.27 on the sheet, (68, 56, 38): the metal mirrored a dark sky. Mostly diffuse now.)
# (Then (0.78, 0.47, 0.1) at metal 0.3: bright but cream-yellow, the squat rounds "a little like propane gas tanks", the
# user. Deeper amber-bronze now, more metallic, smoother for a highlight.)
# (At metal 0.6 it mirrored the dark sky again, brown at 1x: 0.45, still with a highlight.)
BRASS = lpkit.mat("brass", (0.74, 0.45, 0.12), metal=0.45, rough=0.24, grime=0.2)     # worn amber-bronze
lpkit.dirty(BRASS, dirt=0.12, dust=0.08, rust=0.02, scale=6.0)
BAND = M("band", (0.6, 0.17, 0.06), 0.6, 0.3, grime=0.2)             # a shell's copper driving band
SHELL = M("shell", (0.1, 0.115, 0.06), 0.3, 0.5)                     # its projectile, olive drab
MAG_Y = M("mag-y", (0.75, 0.52, 0.02), 0.2, 0.5, grime=0.25)       # vanilla's firearm magazine
MAG_R = M("mag-r", (0.6, 0.06, 0.03), 0.2, 0.5, grime=0.25)        # and its piercing one
# The magazine's olive, greener than PAINT (the army's hue): PAINT's saturation read grey on so small a box.
OLIVE = M("olive", (0.17, 0.27, 0.15), 0.3, 0.6)
if os.path.isdir(lptex.TEX):
    OLIVE = lptex.textured("olive-t", "PaintedMetal006", hue=0.45, sat=0.85, val=0.6, scale=2.5, edge=(0.45, 0.45, 0.42))
# (The textured HAZ's edge wear, its bevel radius wider than the step's small blocks, turned them all off-white.)
HAZ_STEP = M("haz-step", (0.68, 0.48, 0.06), 0.2, 0.6, grime=0.5)
TIP = M("tip", (0.2, 0.15, 0.11), 0.8, 0.4)                                    # the projectile: dark copper-steel


def lathe(profile, x, y, z, mats, split, steps=28, tilt=(0, 0)):
    """A turned part from a profile of (r, h) points, its faces above h = split the second material: a cartridge."""
    import bmesh
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, h)) for r, h in profile]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, axis=(0, 0, 1), cent=(0, 0, 0), steps=steps, angle=2 * math.pi, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new("lathe"); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    for p in me.polygons:
        p.material_index = 1 if p.center.z > split else 0
        p.use_smooth = True
    o = bpy.data.objects.new("lathe", me); scene.collection.objects.link(o)
    o.location = (x, y, z); o.rotation_euler = (tilt[0], tilt[1], tilt[2] if len(tilt) > 2 else 0)
    return o


def supply_depot(f):
    # (The coordinator's pick B of the clay candidates, 2026-11-20, a shell rack round a magazine; 2x2 since the user found
    # 1x1 "unnecessarily tight".) A dark steel skid; slim two-part shells in a dark cradle, two rows standing along the back,
    # stacked lying down each side noses out; the magazine in the middle in the army's olive, its robot hatch two leaves that
    # open for a robot as vanilla's requester door does; a hazard step at the open front between two ammunition crates;
    # vanilla's firearm and piercing magazines littered about. The brass and the magazines' yellow are its saturated parts.
    bevel(B(1.94, 1.94, 0.08, 0, 0, 0, DARK), 0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(0.03, 0.014, sx * 0.9, sy * 0.9, 0.08, STEEL, verts=8)
    for x in (-0.5, 0.5):        # the skid's fork pockets
        B(0.3, 0.02, 0.04, x, -0.965, 0.015, RUBBER, bevel=0.0)
        B(0.02, 0.3, 0.04, -0.965 if x < 0 else 0.965, 0.1, 0.015, RUBBER, bevel=0.0)
    for y in (-0.5, 0.2, 0.62):  # panel seams on the deck
        B(1.86, 0.008, 0.004, 0, y, 0.08, RUBBER, bevel=0.0)
    B(0.008, 1.86, 0.004, 0, 0, 0.08, RUBBER, bevel=0.0)
    for k in range(9):
        B(0.9 / 9, 0.2, 0.03, -0.45 + 0.9 / 9 * (k + 0.5), -0.8, 0.08, HAZ_STEP if k % 2 == 0 else POLE, bevel=0.0)
    # The magazine: an olive box on a dark belt, seams, stencil plates, rivets, handles; its hatch on top.
    zb = 0.08
    bevel(B(0.9, 0.8, 0.05, 0, -0.12, zb, DARK), 0.01)
    bevel(B(0.84, 0.74, 0.34, 0, -0.12, zb + 0.01, OLIVE), 0.035)
    top = zb + 0.35
    for x in (-0.14, 0.14):
        B(0.006, 0.008, 0.3, x, -0.492, zb + 0.03, RUBBER, bevel=0.0)
    B(0.22, 0.014, 0.12, -0.28, -0.492, zb + 0.16, DARK, bevel=0.0)
    B(0.22, 0.014, 0.12, 0.28, -0.492, zb + 0.16, DARK, bevel=0.0)
    for x in (-0.38, 0.38):
        for z in (zb + 0.06, zb + 0.3):
            cyl(0.012, 0.01, x, -0.495, z, STEEL, verts=6, rot=(math.pi / 2, 0, 0))
    for s in (-1, 1):
        rod((s * 0.43, -0.32, zb + 0.26), (s * 0.43, 0.06, zb + 0.26), 0.016, STEEL, verts=6)
    bevel(B(0.62, 0.54, 0.04, 0, -0.12, top, DARK), 0.008)
    B(0.5, 0.42, 0.004, 0, -0.12, top + 0.04, RUBBER, bevel=0.0)          # the well, seen when the leaves part
    for (x, y) in ((-0.14, -0.2), (0.0, -0.06), (0.12, -0.2), (-0.1, 0.0), (0.16, 0.0)):
        cyl(0.06, 0.006, x, y, top + 0.041, BRASS, verts=16)
    leaves = []
    for s in (-1, 1):
        piv = bpy.data.objects.new("hinge", None); scene.collection.objects.link(piv)
        piv.location = (s * 0.25, -0.12, top + 0.04)
        leaf = bevel(B(0.248, 0.46, 0.03, 0, 0, 0, OLIVE), 0.008)
        leaf.parent = piv; leaf.location = (-s * 0.125, 0, 0.015)
        for dy in (-0.12, 0.12):
            rib = B(0.2, 0.025, 0.014, 0, 0, 0, DARK, bevel=0.0); rib.parent = piv; rib.location = (-s * 0.125, dy, 0.037)
        rod((s * 0.25, -0.36, top + 0.055), (s * 0.25, 0.12, top + 0.055), 0.016, DARK, verts=6)
        leaves.append((s, piv))
    # The rounds (the user, of the squat rounds before: "a little like propane gas tanks"): shells, two-part, slim (about
    # 4:1), a case rim, a brass case, a copper driving band, an olive-drab projectile with a tangent-ogive nose and a fuze.
    def shell(R, L, x, y, z, rot=(0, 0), cf=0.4):
        prof = [(0.0, 0.0), (R * 1.08, 0.0), (R * 1.08, 0.025 * L), (R * 0.9, 0.035 * L), (R * 0.9, 0.05 * L), (R, 0.06 * L),
                (R, cf * L), (R * 1.06, (cf + 0.001) * L), (R * 1.06, (cf + 0.04) * L), (R, (cf + 0.041) * L), (R, (cf + 0.1) * L)]
        lo, tip = (0.87 - cf) * L, 0.08 * R        # the ogive: from (cf + 0.1) L to 0.97 L, its tangent arc closing to the fuze
        rho = (R * R + lo * lo) / (2 * R)
        for k in range(1, 9):
            t = lo * k / 8
            r = math.sqrt(max(0.0, rho * rho - t * t)) + R - rho      # (t from the base: R there, 0 at the nose; inverted first, a bulb)
            prof.append((max(tip, r), (cf + 0.1) * L + t))
        prof += [(tip * 0.9, 0.99 * L), (0.0, L)]
        bands = [(cf * L, BRASS), ((cf + 0.041) * L, BAND), (0.965 * L, SHELL), (9.0, STEEL)]
        o = lathe(prof, x, y, z, [m for _, m in bands], 0.0, tilt=rot)
        for p in o.data.polygons:
            p.material_index = next(i for i, (h, _) in enumerate(bands) if p.center.z < h)
        return o
    # (Two standing rows along the back first, 0.2.469: "back row is weird", the user, and "a little too symmetrical and
    # evenly spaced?": dark spikes, the projectiles' paint covering the brass, the front row shading the back's. Now the
    # back is a lying stack on a pallet at the left, a short standing group at the right with more case showing, a gap
    # between where a load has gone; the sides uneven, one full, one half-emptied; strays out of line.)
    # Lying: (x of its base, y, z of its axis, R, L, yaw, nose +1 east / -1 west)
    def lying(x, y, z, R, L, nose, yaw=0.0):
        return shell(R, L, x, y, z, rot=(0, nose * math.pi / 2, yaw))
    # The back's stack, on a dark pallet, noses east: three below, two in their grooves above, one pulled half out.
    bevel(B(0.66, 0.44, 0.04, -0.6, 0.72, zb, POLE), 0.006)
    for xs in (-0.82, -0.42):
        bevel(B(0.05, 0.42, 0.04, xs, 0.72, zb + 0.04, DARK), 0.005)
    R = 0.07
    for k, y in enumerate((0.87, 0.725, 0.58)):
        lying(-0.92 + (0.06 if k == 1 else 0.0), y, zb + 0.08 + R, R, 0.6, 1, yaw=(0.04 if k == 1 else 0.0))
    for y in (0.8, 0.655):
        lying(-0.9, y, zb + 0.08 + R + 0.12, R, 0.58, 1)
    # A short standing group at the back right, the case tall above the cradle (case to 0.6 of its length).
    for k, (x, y, rx, ry) in enumerate(((0.44, 0.84, 0.02, -0.03), (0.63, 0.83, -0.01, 0.02), (0.82, 0.85, 0.03, 0.0),
                                        (0.56, 0.63, -0.09, 0.05))):
        shell(0.08, 0.6 if k < 3 else 0.56, x, y, zb, rot=(rx, ry), cf=0.6)
        lpkit.torus(0.085, 0.011, x, y, zb + 0.04, DARK)
    # One loose in the gap, lying across, noses west.
    lying(0.24, 0.66, zb + 0.065, 0.065, 0.52, -1, yaw=0.35)
    # The sides: saddles, the right full (five below, four above, one pushed out), the left half-emptied (a gap below,
    # two above at one end).
    for s in (-1, 1):
        for xs in (0.56, 0.84):
            bevel(B(0.06, 0.66, 0.05, s * xs, 0.02, zb, DARK), 0.006)
    R = 0.055
    for k, y in enumerate((0.28, 0.15, 0.02, -0.11, -0.24)):
        lying(0.46 + (0.05 if k == 2 else 0.0), y, zb + 0.05 + R, R, 0.46, 1, yaw=(-0.05 if k == 2 else 0.0))
    for y in (0.215, 0.085, -0.045, -0.175):
        lying(0.47, y, zb + 0.05 + R + 0.11, R, 0.44, 1)
    for y in (0.28, 0.15, -0.24):
        lying(-0.46, y, zb + 0.05 + R, R, 0.46, -1)
    for y in (0.215, 0.085):
        lying(-0.47, y, zb + 0.05 + R + 0.11, R, 0.44, -1, yaw=0.03)
    # And one on the skid at the front, set down askew.
    lying(-0.1, -0.91, zb + 0.05, 0.05, 0.42, 1, yaw=-0.12)
    # Vanilla's magazines littered about (the user: "could we show some factorio style magazines littered on the building"):
    # its firearm magazine's curved yellow body (the piercing one red), dark feed lips, a brass round showing at the top.
    def magazine(x, y, z, yaw, pitch, body):
        import bmesh
        bm = bmesh.new()
        n, arc, rad, d, t = 6, math.radians(32), 0.3, 0.085, 0.05
        rings = []
        for i in range(n + 1):
            a = arc * i / n
            c = V((rad * (1 - math.cos(a)), 0, rad * math.sin(a))); nn = V((math.cos(a), 0, -math.sin(a)))
            rings.append([bm.verts.new(c + nn * u + V((0, v, 0))) for (u, v) in
                          ((-d / 2, -t / 2), (d / 2, -t / 2), (d / 2, t / 2), (-d / 2, t / 2))])
        for i in range(n):
            for j in range(4):
                bm.faces.new((rings[i][j], rings[i][(j + 1) % 4], rings[i + 1][(j + 1) % 4], rings[i + 1][j]))
        bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
        me = bpy.data.meshes.new("mag"); bm.to_mesh(me); bm.free()
        me.materials.append(body); me.materials.append(DARK)
        for p in me.polygons:      # the last segment dark: its feed lips
            p.material_index = 1 if p.center.z > rad * math.sin(arc * (n - 1) / n) else 0
        piv = bpy.data.objects.new("magazine", None); scene.collection.objects.link(piv)
        piv.location = (x, y, z); piv.rotation_euler = (pitch, 0, yaw)
        o = bpy.data.objects.new("mag", me); scene.collection.objects.link(o); o.parent = piv
        bevel(o, 0.006, 2)
        top = V((rad * (1 - math.cos(arc)), 0, rad * math.sin(arc))) + V((math.sin(arc), 0, math.cos(arc))) * 0.012
        rd = cyl(0.017, 0.045, 0, 0, 0, BRASS, verts=10, rot=(math.pi / 2, 0, 0)); rd.parent = piv
        rd.location = top
        return piv
    # (x, y, z, yaw, pitch: lying is pi/2 about x; leaning a little off vertical)
    for (x, y, z, yaw, pitch, m) in ((-0.78, -0.72, zb + 0.2 + 0.025, 0.5, math.pi / 2, MAG_Y),
                                     (-0.64, -0.8, zb + 0.2 + 0.025, 2.3, math.pi / 2, MAG_R),
                                     (0.66, -0.7, zb + 0.34 + 0.025, -0.9, math.pi / 2, MAG_Y),
                                     (-0.3, -0.55, zb, 0.0, -0.3, MAG_Y),
                                     (0.27, -0.55, zb, 0.15, -0.35, MAG_Y),
                                     (0.12, -0.76, zb + 0.03 + 0.025, 1.1, math.pi / 2, MAG_Y),
                                     (-0.3, -0.82, zb + 0.025, -0.6, math.pi / 2, MAG_R)):
        magazine(x, y, z, yaw, pitch, m)
    # The cradle: rails at two heights round the back and sides, posts.
    # (Low, at 0.06 and 0.15: at 0.24 the upper rail hid the standing rounds' brass cases.)
    for z in (zb + 0.06, zb + 0.15):
        rod((-0.95, -0.62, z), (-0.95, 0.95, z), 0.02, DARK, verts=6)
        rod((-0.95, 0.95, z), (0.95, 0.95, z), 0.02, DARK, verts=6)
        rod((0.95, 0.95, z), (0.95, -0.62, z), 0.02, DARK, verts=6)
    for (x, y) in ((-0.95, -0.62), (-0.95, 0.95), (0.95, 0.95), (0.95, -0.62), (-0.95, 0.3), (0.95, 0.3), (0.1, 0.95)):
        rod((x, y, zb), (x, y, zb + 0.18), 0.024, DARK, verts=6)
    # Two ammunition crates at the front corners, strapped, a lid each; the right one a second, smaller, on it.
    for (x, y, yaw, w, d, h, z) in ((-0.73, -0.72, 0.22, 0.38, 0.28, 0.2, zb), (0.7, -0.76, -0.14, 0.4, 0.3, 0.2, zb),
                                    (0.66, -0.73, 0.32, 0.28, 0.2, 0.14, zb + 0.2)):
        bevel(B(w, d, h, x, y, z, OLIVE, rot=yaw), 0.015)
        B(w + 0.01, d + 0.01, 0.025, x, y, z + h - 0.025, DARK, rot=yaw, bevel=0.0)
        for t in (-0.3, 0.3):
            B(0.025, d + 0.012, h - 0.03, x + t * w * math.cos(yaw), y + t * w * math.sin(yaw), z, DARK, rot=yaw, bevel=0.0)

    def door(fr):
        a = math.radians(105) * fr / (DEPOT_FRAMES - 1)
        for s, piv in leaves:
            piv.rotation_euler = (0, s * a, 0)
        bpy.context.view_layer.update()
    ANIM["supply-depot"] = door


MODELS = {"rally-beacon": (rally_beacon, ["north", "east", "south", "west"]),
          "supply-depot": (supply_depot, ["north"]),
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


FRAMES = {"supply-depot": DEPOT_FRAMES}   # a model's own frame count (else GLOW_FRAMES)
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
        for f in range(FRAMES.get(name, GLOW_FRAMES)):
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
                # (Directly, as faction_works.py's pylon: x right, y + z up the stretched sheet. Through the camera's
                # frame, 8 wide and 6 tall here, the heights came out a third too high, 2026-11-17.)
                gp = wp + light * (wp.z / max(1e-3, -light.z))
                pts[col] = {"wire": [round(wp.x, 3), round(-(wp.y + wp.z), 3)],
                            "shadow": [round(gp.x, 3), round(-(gp.y + gp.z), 3)]}
            meta[d] = pts
        print("rendered", name, d)
    if meta:
        json.dump(meta, open(f"{out}/{name}/posts.json", "w"), indent=1)
    for m in model + [rig]:
        bpy.data.objects.remove(m, do_unlink=True)
