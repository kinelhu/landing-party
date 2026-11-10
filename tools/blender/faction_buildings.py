"""The factions' buildings, modelled (the user, 2026-11-10: "I still see some gross recolors. Why not use blender
again?"): each was a vanilla sprite repainted. One model a role, two faction versions: Kessler-Hayashi's clean corporate
blue-grey with cyan lights, Grubstake's patched ochre scrap with amber, and each its own details. A still body, its
lights GLOW_FRAMES times, a shadow (cannon_sheets.py), one direction.

    Blender -b -P tools/blender/faction_buildings.py -- <out dir> <building> [kh|gs ...]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, mathutils
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
out, what = args[0], args[1]
factions = args[2:] or ["kh", "gs"]
GLOW_FRAMES = int(os.environ.get("LP_FRAMES", 8))
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
lpkit.gpu(scene)
V = mathutils.Vector
B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere
TEX = os.path.isdir(lptex.TEX)


def M(n, rgb, metal=0.5, rough=0.5, emit=None, strength=0.0, grime=0.5):
    return lpkit.mat(n, rgb, metal=metal, rough=rough, emit=emit, strength=strength, grime=grime)


def palette(f):
    """A faction's materials: hull, trim, dark, steel, accent, light."""
    if f == "kh":
        hull = lptex.textured("kh-hull", "PaintedMetal006", hue=0.62, sat=0.35, val=0.5, scale=0.8, edge=(0.48, 0.49, 0.5)) if TEX \
            else M("kh-hull", (0.18, 0.23, 0.3), 0.4, 0.5)
        trim = M("kh-trim", (0.62, 0.62, 0.6), 0.3, 0.5, grime=0.3)
        accent = lptex.textured("kh-haz", "PaintedMetal004", hue=0.66, sat=0.5, val=0.6, scale=1.0, edge=(0.4, 0.4, 0.38)) if TEX \
            else M("kh-haz", (0.62, 0.5, 0.1), 0.2, 0.6)
        light = M("kh-light", (0.2, 0.5, 0.6), 0.2, 0.3, emit=(0.45, 0.85, 1.0), strength=0.0)
    else:
        hull = lpkit.mat("gs-hull", (0.36, 0.22, 0.05), metal=0.3, rough=0.65, grime=0.85)
        trim = lptex.textured("gs-rust", "MetalPlates013", val=0.6, scale=0.8, edge=(0.4, 0.33, 0.25)) if TEX \
            else M("gs-rust", (0.25, 0.11, 0.05), 0.5, 0.7)
        accent = M("gs-red", (0.4, 0.08, 0.05), 0.3, 0.6, grime=0.8)
        light = M("gs-light", (0.6, 0.4, 0.05), 0.1, 0.3, emit=(1.0, 0.62, 0.15), strength=0.0)
    dark = lptex.textured(f + "-dark", "Metal038", val=0.3, scale=1.0, edge=(0.3, 0.3, 0.29), dirt=0.6, rough_add=0.25) if TEX \
        else M(f + "-dark", (0.06, 0.065, 0.07), 0.6, 0.55)
    steel = lptex.textured(f + "-steel", "Metal038", val=0.7, scale=1.0, edge=(0.5, 0.5, 0.5), dirt=0.7, rough_add=0.1) if TEX \
        else M(f + "-steel", (0.3, 0.31, 0.33), 0.8, 0.4)
    return {"hull": hull, "trim": trim, "dark": dark, "steel": steel, "accent": accent, "light": light}


def bevel(o, w=0.05, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"; return o


def loft(sections, m, closed=True):
    """A hull through cross-sections: [(y, [(x, z), ...]), ...], each ring the same count of points."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, z in pts] for y, pts in sections]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if closed:
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("loft"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("loft", me); scene.collection.objects.link(o); me.materials.append(m)
    return bevel(o, 0.08, 3)


def hull_ring(w, h, c=0.35):
    """A rounded box section, width w and height h, standing on z 0 (eight points)."""
    return [(-w / 2 + c, 0), (w / 2 - c, 0), (w / 2, c), (w / 2, h - c), (w / 2 - c, h), (-w / 2 + c, h), (-w / 2, h - c), (-w / 2, c)]


# --- The landers: 15.6 by 7.8 tiles, its middle 0.9 west and 0.6 south of the entity's (the ship's footprint) --------
def lander(f, P):
    cx, cy = -0.9, -0.6          # (Blender's y is north)
    def at(x, y): return cx + x, cy + y
    if f == "kh":
        # A corporate drop ship, lying east-west: a long armoured hull on four landing legs, its nose east, its engine
        # block west, a ramp down to the south, a comms mast, the trim's stripes.
        secs = []
        for x, w, h in ((-7.2, 3.6, 2.6), (-6.0, 5.2, 3.2), (-2.0, 5.8, 3.4), (2.5, 5.4, 3.0), (5.2, 3.6, 2.2), (6.6, 1.6, 1.2)):
            secs.append((x, hull_ring(w, h, 0.6)))
        hull = loft([(y, [(z_x, z_z) for z_x, z_z in pts]) for y, pts in secs], P["hull"])
        # (Lofted along y, laid along x: turned a quarter, raised onto its legs.)
        hull.rotation_euler = (0, 0, math.radians(-90)); hull.location = (cx, cy, 0.9)
        for x, y in ((-4.5, -2.3), (-4.5, 2.3), (3.2, -2.1), (3.2, 2.1)):
            px, py = at(x, y)
            rod((px * 0.8 + cx * 0.2, py * 0.6 + cy * 0.4, 1.6), (px, py, 0.15), 0.18, P["steel"], verts=10)
            bevel(B(0.9, 0.9, 0.16, px, py, 0, P["dark"]), 0.04)
        # The engine block west: three bells, lit inside.
        for k, z in enumerate((1.4, 2.6, 2.0)):
            yy = (-1.4, 0.0, 1.4)[k]
            bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.9, radius2=0.55, depth=1.2, location=(cx - 7.9, cy + yy, z),
                                            rotation=(0, math.pi / 2, 0))
            bpy.context.object.data.materials.append(P["dark"])
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.6, depth=0.05, location=(cx - 8.45, cy + yy, z), rotation=(0, math.pi / 2, 0))
            bpy.context.object.data.materials.append(P["light"])
        # The ramp down to the south, its edges striped.
        rx, ry = at(-0.5, -3.4)
        o = bevel(B(2.6, 2.8, 0.15, rx, ry + 0.6, 0.1, P["steel"]), 0.03); o.rotation_euler = (math.radians(18), 0, 0)
        for sx in (-1, 1):
            o = B(0.12, 2.8, 0.05, rx + sx * 1.25, ry + 0.6, 0.27, P["accent"], bevel=0.0); o.rotation_euler = (math.radians(18), 0, 0)
        # Its spine: stripes, hatches, a comms mast and dish, lights along the flanks.
        for x in (-5.5, -1.5, 2.5):
            B(0.5, 5.4, 0.04, cx + x, cy, 4.3, P["accent"], bevel=0.0)
        for x in (-3.5, 0.5):
            bevel(B(1.4, 1.4, 0.2, cx + x, cy + 0.6, 4.3, P["dark"]), 0.04)
        rod((cx + 1.8, cy + 1.2, 4.3), (cx + 1.8, cy + 1.2, 6.4), 0.06, P["steel"], verts=8)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.6, location=(cx + 1.8, cy + 1.2, 5.6), segments=32, ring_count=16)
        o = bpy.context.object; o.scale = (1, 0.35, 1); o.rotation_euler = (0.5, 0, 0.6); o.data.materials.append(P["trim"])
        sph(0.09, cx + 1.8, cy + 1.2, 6.45, P["light"])
        for x in range(-6, 6, 2):
            for sy in (-1, 1):
                B(0.25, 0.04, 0.08, cx + x, cy + sy * 2.85, 2.6, P["light"], bevel=0.0)
        # Cargo crates and a fuel line on the ground by the ramp.
        for k in range(3):
            bevel(B(0.9, 0.9, 0.8, cx + 2.5 + k * 1.0, cy - 3.6, 0, P["trim"] if k % 2 else P["hull"]), 0.04)
    else:
        # A patched prospecting hulk: a stubby welded hull tipped on its skids, cargo pods strapped on, a drill rig
        # west, scrap plates bolted over its holes, a smokestack.
        secs = []
        for x, w, h in ((-6.5, 4.0, 2.4), (-4.0, 5.4, 3.0), (0.0, 5.8, 3.3), (3.5, 5.0, 2.8), (6.0, 3.2, 1.8)):
            secs.append((x, hull_ring(w, h, 0.4)))
        hull = loft(secs, P["hull"])
        hull.rotation_euler = (math.radians(4), 0, math.radians(-90)); hull.location = (cx, cy, 0.5)
        for sy in (-1, 1):
            bevel(B(13.5, 0.5, 0.35, cx, cy + sy * 2.6, 0, P["trim"]), 0.05)
        # Its patches: plates bolted on askew.
        for x, y, z, r in ((-3.0, -2.95, 2.0, 8), (1.0, -2.9, 1.6, -6), (4.0, 2.7, 2.2, 10), (-1.5, 2.95, 2.6, -12), (-5.0, 0.5, 3.5, 4)):
            o = B(1.4, 0.06 if abs(y) > 2 else 1.2, 1.0 if abs(y) > 2 else 0.06, cx + x, cy + y, z, P["trim"], bevel=0.02)
            o.rotation_euler = (0, math.radians(r), 0)
        # Cargo pods strapped on its back, two lying, one standing.
        for k, (x, y) in enumerate(((-2.0, 1.0), (0.4, 1.2), (2.6, -0.8))):
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.65, depth=2.0, location=(cx + x, cy + y, 4.2), rotation=(0, math.pi / 2, 0))
            o = bpy.context.object; o.data.materials.append(P["accent"] if k == 1 else P["steel"]); bevel(o, 0.04)
            for dx in (-0.6, 0.6):
                lpkit.torus(0.67, 0.04, cx + x + dx, cy + y, 4.2, P["dark"]).rotation_euler = (0, math.pi / 2, 0)
        # The drill rig west: a derrick frame, its bit, a winch.
        dx, dy = cx - 7.4, cy - 0.5
        for sx in (-1, 1):
            for sy in (-1, 1):
                rod((dx + sx * 0.9, dy + sy * 0.9, 0), (dx, dy, 4.8), 0.08, P["steel"], verts=6)
        for z in (1.2, 2.4, 3.6):
            k = 1 - z / 4.8
            for a, b in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
                rod((dx + a[0] * 0.9 * k, dy + a[1] * 0.9 * k, z), (dx + b[0] * 0.9 * k, dy + b[1] * 0.9 * k, z), 0.04, P["steel"], verts=5)
        cyl(0.25, 1.2, dx, dy, 0, P["dark"], verts=16)
        bevel(B(1.0, 0.8, 0.7, dx + 1.4, dy - 1.4, 0, P["trim"]), 0.04)
        # A smokestack, lamps, a radio aerial.
        cyl(0.35, 2.4, cx + 4.5, cy + 0.6, 3.0, P["dark"], verts=16)
        lpkit.torus(0.37, 0.05, cx + 4.5, cy + 0.6, 5.2, P["trim"])
        for x in (-4.0, 0.0, 4.0):
            sph(0.12, cx + x, cy - 3.0, 2.4, P["light"])
        rod((cx + 5.6, cy - 0.5, 3.6), (cx + 5.8, cy - 0.6, 6.0), 0.03, P["steel"], verts=5)
        for k in range(4):
            bevel(B(0.8, 0.8, 0.7, cx + 3.0 + (k % 2) * 0.9, cy - 3.7 - (k // 2) * 0.9, 0, P["trim"] if k % 2 else P["accent"]), 0.03)


MODELS = {"lander": (lander, 17.5)}
model_fn, span = MODELS[what]
FILL = 0.38
ground, sun, world = lpkit.stage(scene, span, 0)
sun.data.energy = 3.4; sun.data.angle = math.radians(1.5)
bg = world.node_tree.nodes["Background"]
for f in factions:
    P = palette(f)
    before = set(scene.objects)
    model_fn(f, P)
    model = [o for o in scene.objects if o not in before]
    lights = {P["light"]}
    o = f"{out}/{what}-{f}/north"
    for k in ("body", "glow"): os.makedirs(f"{o}/{k}", exist_ok=True)
    for fr in range(GLOW_FRAMES):
        t = fr / GLOW_FRAMES
        lpkit.emission(P["light"], 2.0 + 1.0 * math.sin(t * 2 * math.pi))
        if fr == 0:
            ground.hide_render = True; sun.hide_render = False; bg.inputs[1].default_value = FILL
            for m in model: m.is_holdout = False
            lpkit.render(scene, f"{o}/body/000.png")
        ground.hide_render = True; sun.hide_render = True; bg.inputs[1].default_value = 0.0
        for m in model:
            ms = [s.material for s in m.material_slots if s.material]
            m.is_holdout = not any(x in lights for x in ms)
        lpkit.render(scene, f"{o}/glow/{fr:03d}.png")
    for m in model: m.is_holdout = False; m.visible_camera = False
    sun.hide_render = False; bg.inputs[1].default_value = FILL; ground.hide_render = False
    lpkit.render(scene, f"{o}/shadow.png")
    for m in model: bpy.data.objects.remove(m, do_unlink=True)
    print("rendered", what, f)
