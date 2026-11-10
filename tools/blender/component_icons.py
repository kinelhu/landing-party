"""Icons for the mod's components (the user, 2026-11-10: items and technologies all reused vanilla icons; "Do all"): a
small model each, rendered as vanilla's icons are, a three-quarter view, a strong key light, no ground shadow, on
transparency, SIZE px square (tools/icons/cut.py makes the 64 px icons). The materials are orbital_cannon.py's kind: CC0
textures where LP_TEX has them, lpkit's otherwise.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/component_icons.py -- <out dir> [name ...]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, mathutils
import lpkit, lptex

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = set(args[1:])
SIZE = int(os.environ.get("LP_ICON", 512))
scene = lpkit.reset(); scene.cycles.samples = int(os.environ.get("LP_SAMPLES", 64))
os.makedirs(out, exist_ok=True)
V = mathutils.Vector
P = lpkit.palette_worn()


def mat(name, rgb, metal=0.5, rough=0.45, emit=None, strength=0.0):
    return lpkit.mat(name, rgb, metal=metal, rough=rough, emit=emit, strength=strength, grime=0.25)


STEEL = mat("steel", (0.36, 0.37, 0.39), 0.85, 0.35)
DARK = mat("dark", (0.07, 0.075, 0.08), 0.6, 0.5)
TUNG = mat("tungsten", (0.2, 0.21, 0.23), 0.9, 0.3)
COPPER = mat("copper", (0.62, 0.32, 0.15), 1.0, 0.3)
GOLD = mat("gold", (0.85, 0.62, 0.2), 1.0, 0.25)
CYAN = mat("cyan", (0.2, 0.5, 0.6), 0.2, 0.3, emit=(0.45, 0.85, 1.0), strength=1.3)
RED = mat("red", (0.5, 0.05, 0.03), 0.2, 0.4, emit=(1.0, 0.15, 0.08), strength=1.2)
HAZ = mat("hazard", (0.78, 0.6, 0.1), 0.2, 0.55)
PAINT = mat("paint", (0.16, 0.24, 0.29), 0.3, 0.55)
OLIVE = mat("olive", (0.35, 0.4, 0.15), 0.25, 0.5)
GLAND = mat("gland", (0.22, 0.3, 0.08), 0.0, 0.12, emit=(0.45, 0.8, 0.15), strength=0.25)
VEIN = mat("vein", (0.5, 0.12, 0.25), 0.0, 0.3, emit=(0.9, 0.2, 0.5), strength=1.2)
CRYSTAL = mat("crystal", (0.42, 0.22, 0.65), 0.1, 0.08, emit=(0.6, 0.35, 1.0), strength=1.5)
PAPER = mat("paper", (0.18, 0.35, 0.62), 0.0, 0.8)
INK = mat("ink", (0.85, 0.9, 1.0), 0.0, 0.7, emit=(0.8, 0.88, 1.0), strength=0.4)
BRASS = mat("brass", (0.7, 0.52, 0.22), 0.9, 0.35)
# (Textured where the CC0 sets are: the cannon's grime on the metals and paint; clean CG read as plastic.)
if os.path.isdir(lptex.TEX):
    STEEL = lptex.textured("steel-t", "Metal038", val=0.8, scale=3.0, edge=(0.55, 0.55, 0.55), dirt=0.6, rough_add=0.05)
    DARK = lptex.textured("dark-t", "Metal038", val=0.32, scale=3.0, edge=(0.32, 0.32, 0.31), dirt=0.6, rough_add=0.2)
    TUNG = lptex.textured("tung-t", "Metal038", val=0.5, sat=0.5, scale=3.0, edge=(0.45, 0.45, 0.45), dirt=0.6)
    PAINT = lptex.textured("paint-t", "PaintedMetal006", hue=0.58, sat=0.45, val=0.6, scale=2.5, edge=(0.45, 0.45, 0.43))
    HAZ = lptex.textured("haz-t", "PaintedMetal004", hue=0.66, sat=0.6, val=0.7, scale=2.5, edge=(0.45, 0.43, 0.4), rough_add=0.2)
    OLIVE = lptex.textured("olive-t", "PaintedMetal006", hue=0.42, sat=0.5, val=0.55, scale=2.5, edge=(0.45, 0.45, 0.4))

B, cyl, rod, sph = lpkit.box, lpkit.cyl, lpkit.rod, lpkit.sphere


def lying(r, h, x, y, z, m, verts=32, axis="x"):
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(x, y, z), rotation=rot)
    o = bpy.context.object; o.data.materials.append(m); return o


def cone(r1, r2, h, x, y, z, m, verts=32, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=(x, y, z + h / 2), rotation=rot)
    o = bpy.context.object; o.data.materials.append(m); return o


def bevel(o, w=0.03, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"; return o


# --- The models (each about a unit across, standing on z = 0) -----------------------------------------------------
def command_core():
    bevel(B(1.1, 1.1, 0.35, 0, 0, 0, DARK), 0.06)
    bevel(B(0.95, 0.95, 0.12, 0, 0, 0.35, PAINT), 0.03)
    cyl(0.28, 0.08, 0, 0, 0.47, CYAN, verts=6)
    lpkit.torus(0.3, 0.035, 0, 0, 0.52, STEEL)
    for s in (-1, 1):
        for k in range(6):
            B(0.06, 0.16, 0.06, -0.4 + k * 0.16, s * 0.6, 0.12, GOLD, bevel=0.005)
            B(0.16, 0.06, 0.06, s * 0.6, -0.4 + k * 0.16, 0.12, GOLD, bevel=0.005)
    B(0.3, 0.08, 0.02, 0.22, -0.3, 0.47, HAZ, bevel=0.0)


def pheromone_gland():
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(0, 0, 0.45), segments=48, ring_count=24)
    o = bpy.context.object; o.scale = (1.0, 0.8, 0.9); o.data.materials.append(GLAND)
    md = o.modifiers.new("d", "DISPLACE"); t = bpy.data.textures.new("n", "CLOUDS"); t.noise_scale = 0.35; md.texture = t
    md.strength = 0.12
    for k in range(7):
        a = k * 2 * math.pi / 7
        pts = [(math.cos(a) * 0.45, math.sin(a) * 0.36, 0.2 + 0.1 * (k % 2)), (math.cos(a + 0.4) * 0.38, math.sin(a + 0.4) * 0.3, 0.7),
               (math.cos(a + 0.7) * 0.15, math.sin(a + 0.7) * 0.12, 0.85)]
        for p0, p1 in zip(pts, pts[1:]):
            rod(p0, p1, 0.025, VEIN, verts=6)
    cone(0.12, 0.04, 0.18, 0, 0, 0.85, VEIN, verts=12)
    for k in range(3):
        a = k * 2.1
        sph(0.12, math.cos(a) * 0.36, math.sin(a) * 0.28, 0.25, GLAND)


def pacifier_crystal():
    bevel(cyl(0.45, 0.16, 0, 0, 0, STEEL, verts=8), 0.03)
    for k, (x, y, h, r, tilt) in enumerate(((0, 0, 0.9, 0.17, 0), (0.22, 0.08, 0.6, 0.12, 0.25), (-0.2, 0.12, 0.65, 0.12, -0.3),
                                           (0.05, -0.22, 0.5, 0.1, 0.2), (-0.12, -0.15, 0.45, 0.09, -0.2))):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=h, location=(x, y, 0.16 + h / 2), rotation=(tilt, tilt * 0.5, 0))
        o = bpy.context.object; o.data.materials.append(CRYSTAL)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=0, depth=r * 1.6,
                                        location=(x + math.sin(tilt * 0.5) * h / 2, y - math.sin(tilt) * h / 2, 0.16 + h + r * 0.8),
                                        rotation=(tilt, tilt * 0.5, 0))
        bpy.context.object.data.materials.append(CRYSTAL)


def drill_head():
    # Point down: a fluted tungsten cone, its hex shank and collar on top.
    cone(0.06, 0.42, 0.75, 0, 0, 0, TUNG, verts=24)
    cyl(0.16, 0.35, 0, 0, 0.75, DARK, verts=6)
    lpkit.torus(0.2, 0.045, 0, 0, 0.8, HAZ)
    for k in range(22):
        t = k / 22
        a = t * 5 * math.pi
        r = 0.06 + 0.37 * t + 0.02
        z = 0.03 + t * 0.7
        a2, t2 = a + 0.75, min(1, t + 1 / 22)
        r2, z2 = 0.06 + 0.37 * t2 + 0.02, 0.03 + t2 * 0.7
        rod((math.cos(a) * r, math.sin(a) * r, z), (math.cos(a2) * r2, math.sin(a2) * r2, z2), 0.03, STEEL, verts=6)


def rail_coil():
    lying(0.45, 0.12, -0.42, 0, 0.5, DARK); lying(0.45, 0.12, 0.42, 0, 0.5, DARK)
    lying(0.18, 0.95, 0, 0, 0.5, STEEL)
    for k in range(13):
        x = -0.33 + k * 0.055
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.035, location=(x, 0, 0.5), rotation=(0, math.pi / 2, 0),
                                         major_segments=32, minor_segments=8)
        bpy.context.object.data.materials.append(COPPER)
    lying(0.08, 1.05, 0, 0, 0.5, CYAN, verts=16)


def cluster_fuze():
    cyl(0.26, 0.5, 0, 0, 0, STEEL, verts=24)
    cone(0.26, 0.08, 0.35, 0, 0, 0.5, BRASS, verts=24)
    for z in (0.12, 0.3):
        lpkit.torus(0.27, 0.03, 0, 0, z, HAZ)
    for k in range(4):
        a = k * math.pi / 2
        o = B(0.04, 0.22, 0.28, math.cos(a) * 0.3, math.sin(a) * 0.3, 0.02, DARK, rot=a, bevel=0.005)
    sph(0.05, 0, 0, 0.88, RED)


def orbital_beacon():
    bevel(B(0.8, 0.6, 0.45, 0, 0, 0, PAINT), 0.05)
    bevel(B(0.7, 0.5, 0.1, 0, 0, 0.45, DARK), 0.02)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(-0.1, 0, 0.75), segments=32, ring_count=16)
    o = bpy.context.object; o.scale = (1, 1, 0.35); o.rotation_euler = (0.5, -0.3, 0); o.data.materials.append(STEEL)
    rod((-0.1, 0, 0.6), (-0.1, 0, 0.78), 0.03, DARK)
    rod((0.25, 0.15, 0.55), (0.3, 0.18, 1.05), 0.015, STEEL)
    sph(0.04, 0.3, 0.18, 1.06, RED)
    for k in range(3):
        B(0.08, 0.02, 0.06, -0.25 + k * 0.12, -0.31, 0.25, CYAN, bevel=0.0)


def schematic():
    o = bevel(B(1.0, 0.75, 0.02, 0, 0, 0, PAPER), 0.005)
    for k in range(7):
        B(0.85, 0.006, 0.004, 0, -0.3 + k * 0.1, 0.02, INK, bevel=0.0)
        B(0.006, 0.65, 0.004, -0.42 + k * 0.14, 0, 0.02, INK, bevel=0.0)
    lying(0.08, 0.8, 0, 0.4, 0.06, PAPER, axis="x")
    lying(0.085, 0.82, 0, 0.4, 0.06, INK, axis="x").scale = (1, 1, 1)


def orbital_shell():
    cyl(0.24, 0.95, 0, 0, 0, TUNG, verts=32)
    cone(0.24, 0.02, 0.5, 0, 0, 0.95, DARK, verts=32)
    for z, m in ((0.1, COPPER), (0.2, COPPER), (0.7, CYAN)):
        lpkit.torus(0.245, 0.03, 0, 0, z, m)
    B(0.12, 0.02, 0.1, 0, -0.24, 0.45, HAZ, bevel=0.0)


def targeting_core():
    bevel(B(1.0, 1.0, 0.4, 0, 0, 0, PAINT), 0.08)
    cyl(0.32, 0.12, 0, 0, 0.4, DARK, verts=32)
    sph(0.24, 0, 0, 0.5, CYAN)
    for s in (-1, 1):
        for k in range(5):
            B(0.07, 0.14, 0.07, -0.32 + k * 0.16, s * 0.55, 0.12, GOLD, bevel=0.005)
    B(0.24, 0.06, 0.02, -0.3, 0.38, 0.4, HAZ, bevel=0.0)


def defoliant():
    cyl(0.28, 0.75, 0, 0, 0, OLIVE, verts=32)
    cone(0.28, 0.1, 0.2, 0, 0, 0.75, STEEL, verts=32)
    cyl(0.06, 0.12, 0, 0, 0.95, DARK, verts=12)
    for z in (0.15, 0.6):
        lpkit.torus(0.285, 0.025, 0, 0, z, HAZ)
    B(0.3, 0.02, 0.2, 0, -0.28, 0.3, HAZ, bevel=0.0)


def mortar_shell():
    cyl(0.2, 0.5, 0, 0, 0.2, DARK, verts=24)
    cone(0.2, 0.02, 0.35, 0, 0, 0.7, STEEL, verts=24)
    cone(0.08, 0.2, 0.2, 0, 0, 0.0, DARK, verts=24)
    for k in range(4):
        a = k * math.pi / 2
        B(0.03, 0.18, 0.2, math.cos(a) * 0.12, math.sin(a) * 0.12, 0.0, STEEL, rot=a, bevel=0.0)
    lpkit.torus(0.205, 0.025, 0, 0, 0.6, HAZ)


def rail_slug():
    bevel(B(0.5, 0.35, 0.6, 0, 0, 0, DARK), 0.03)
    bevel(B(0.4, 0.25, 0.1, 0, 0, 0.6, STEEL), 0.01)
    for k in range(3):
        x = -0.12 + k * 0.12
        cyl(0.045, 0.3, x, 0, 0.7, TUNG, verts=12)
        cone(0.045, 0.01, 0.1, x, 0, 1.0, CYAN, verts=12)
    B(0.3, 0.02, 0.12, 0, -0.18, 0.3, HAZ, bevel=0.0)


def cluster_artillery_shell():
    cyl(0.22, 0.9, 0, 0, 0, STEEL, verts=32)
    cone(0.22, 0.03, 0.45, 0, 0, 0.9, DARK, verts=32)
    for k in range(5):
        lpkit.torus(0.225, 0.03, 0, 0, 0.12 + k * 0.17, HAZ if k % 2 else RED)


def rail_rifle():
    # Chunky, short for an icon: a receiver, a coil-wound barrel, a stock, a magazine.
    bevel(B(0.3, 0.6, 0.32, 0, -0.05, 0.0, DARK), 0.03)
    bevel(B(0.24, 0.42, 0.26, 0, -0.55, -0.02, PAINT), 0.03)
    lying(0.09, 0.8, 0, 0.62, 0.17, STEEL, axis="y")
    for k in range(5):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.04, location=(0, 0.35 + k * 0.12, 0.17),
                                         rotation=(math.pi / 2, 0, 0), major_segments=24, minor_segments=8)
        bpy.context.object.data.materials.append(COPPER)
    bevel(B(0.12, 0.18, 0.3, 0, 0.0, -0.3, DARK), 0.02)
    B(0.06, 0.4, 0.05, 0, 0.0, 0.32, CYAN, bevel=0.0)
    B(0.28, 0.12, 0.05, 0, -0.32, 0.26, HAZ, bevel=0.0)


TILT = {"drill-head": (0, -100, 0)}
MODELS = {"command-core": command_core, "pheromone-gland": pheromone_gland, "pacifier-crystal": pacifier_crystal,
          "drill-head": drill_head, "rail-coil": rail_coil, "cluster-fuze": cluster_fuze, "orbital-beacon": orbital_beacon,
          "schematic": schematic, "orbital-shell": orbital_shell, "targeting-core": targeting_core, "defoliant": defoliant,
          "mortar-shell": mortar_shell, "rail-slug": rail_slug, "cluster-artillery-shell": cluster_artillery_shell,
          "rail-rifle": rail_rifle}

# --- The stage: a key light from the upper left, a fill, the camera from the south at 45 degrees, the model turned 30 ---
bpy.ops.object.light_add(type="SUN", location=(0, 0, 10)); sun = bpy.context.object
sun.data.energy = 4.0; sun.data.angle = math.radians(4); sun.rotation_euler = (math.radians(45), 0, math.radians(-40))
world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.82, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
bpy.ops.object.camera_add(location=(0, -10, 10), rotation=(math.radians(45), 0, 0)); cam = bpy.context.object
cam.data.type = "ORTHO"; scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = SIZE
for name, fn in MODELS.items():
    if only and name not in only:
        continue
    before = set(scene.objects)
    fn()
    objs = [o for o in scene.objects if o not in before]
    # (Some lie on their side: a drill head stood on its point showed only its shank from above.)
    tilt = bpy.data.objects.new("tilt", None); scene.collection.objects.link(tilt)
    tilt.rotation_euler = tuple(math.radians(v) for v in TILT.get(name, (0, 0, 0)))
    for o in objs:
        if o.parent is None: o.parent = tilt
    rig = bpy.data.objects.new("rig", None); scene.collection.objects.link(rig)
    tilt.parent = rig
    rig.rotation_euler = (0, 0, math.radians(30))
    bpy.context.view_layer.update()
    # Framed on what the camera sees of it: its corners in the camera's view.
    from bpy_extras.object_utils import world_to_camera_view
    pts = [o.matrix_world @ V(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    cx = sum(p.x for p in pts) / len(pts); cy = sum(p.y for p in pts) / len(pts); cz = sum(p.z for p in pts) / len(pts)
    cam.location = (cx, cy - 10, cz + 10)
    bpy.context.view_layer.update()
    cam.data.ortho_scale = 10
    bpy.context.view_layer.update()
    vs = [world_to_camera_view(scene, cam, p) for p in pts]
    span = max(max(v.x for v in vs) - min(v.x for v in vs), max(v.y for v in vs) - min(v.y for v in vs))
    cam.data.ortho_scale = 10 * span * 1.12
    bpy.context.view_layer.update()
    vs = [world_to_camera_view(scene, cam, p) for p in pts]
    dx = (max(v.x for v in vs) + min(v.x for v in vs)) / 2 - 0.5
    dy = (max(v.y for v in vs) + min(v.y for v in vs)) / 2 - 0.5
    right = cam.matrix_world.to_quaternion() @ V((1, 0, 0)); up = cam.matrix_world.to_quaternion() @ V((0, 1, 0))
    cam.location = cam.location + right * dx * cam.data.ortho_scale + up * dy * cam.data.ortho_scale
    lpkit.render(scene, os.path.join(out, name + ".png"))
    for o in objs + [tilt, rig]:
        bpy.data.objects.remove(o, do_unlink=True)
    print("icon", name)
